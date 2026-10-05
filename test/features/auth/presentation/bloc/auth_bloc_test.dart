import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/auth/domain/entities/sign_up_result.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:finly/features/auth/domain/usecases/get_current_user_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_in_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_out_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_up_use_case.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/bloc/auth_event.dart';
import 'package:finly/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSignIn extends Mock implements SignInUseCase {}

class MockSignUp extends Mock implements SignUpUseCase {}

class MockSignOut extends Mock implements SignOutUseCase {}

class MockGetCurrentUser extends Mock implements GetCurrentUserUseCase {}

void main() {
  late MockSignIn signIn;
  late MockSignUp signUp;
  late MockSignOut signOut;
  late MockGetCurrentUser getCurrentUser;

  const user = UserEntity(
    id: 'u1',
    fullName: 'Ana Teste',
    email: 'ana@finly.com',
    workspaces: [],
  );
  const signInParams =
      SignInParams(email: 'ana@finly.com', password: 'secret123');
  const signUpParams = SignUpParams(
    fullName: 'Ana Teste',
    email: 'ana@finly.com',
    password: 'secret123',
    acceptedTerms: true,
  );
  const signUpEvent = SignUpSubmitted(
    fullName: 'Ana Teste',
    email: 'ana@finly.com',
    password: 'secret123',
    acceptedTerms: true,
  );

  setUp(() {
    signIn = MockSignIn();
    signUp = MockSignUp();
    signOut = MockSignOut();
    getCurrentUser = MockGetCurrentUser();
  });

  AuthBloc buildBloc() => AuthBloc(
        signIn: signIn,
        signUp: signUp,
        signOut: signOut,
        getCurrentUser: getCurrentUser,
      );

  test('starts in the initial state', () {
    expect(buildBloc().state, const AuthState.initial());
  });

  group('session restore', () {
    blocTest<AuthBloc, AuthState>(
      'is authenticated when a stored session exists',
      build: () {
        when(() => getCurrentUser(const NoParams()))
            .thenAnswer((_) async => const Right<Failure, UserEntity?>(user));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [const AuthState.authenticated(user)],
    );

    blocTest<AuthBloc, AuthState>(
      'is unauthenticated when there is no stored session',
      build: () {
        when(() => getCurrentUser(const NoParams()))
            .thenAnswer((_) async => const Right<Failure, UserEntity?>(null));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [const AuthState.unauthenticated()],
    );

    blocTest<AuthBloc, AuthState>(
      'starts signed out, without an error, when the session cannot be loaded',
      build: () {
        when(() => getCurrentUser(const NoParams())).thenAnswer(
          (_) async => const Left<Failure, UserEntity?>(
            NetworkFailure('network_error'),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthStarted()),
      expect: () => [const AuthState.unauthenticated()],
    );
  });

  group('sign in', () {
    blocTest<AuthBloc, AuthState>(
      'emits loading then authenticated on success',
      build: () {
        when(() => signIn(signInParams))
            .thenAnswer((_) async => const Right<Failure, UserEntity>(user));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const SignInSubmitted(email: 'ana@finly.com', password: 'secret123'),
      ),
      expect: () => [
        const AuthState.loading(),
        const AuthState.authenticated(user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits loading then failed on a wrong password',
      build: () {
        when(() => signIn(signInParams)).thenAnswer(
          (_) async => const Left<Failure, UserEntity>(
            AuthFailure('invalid_credentials'),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const SignInSubmitted(email: 'ana@finly.com', password: 'secret123'),
      ),
      expect: () => [
        const AuthState.loading(),
        const AuthState.failed(AuthFailure('invalid_credentials')),
      ],
    );
  });

  group('sign up', () {
    blocTest<AuthBloc, AuthState>(
      'waits for e-mail confirmation when there is no session',
      build: () {
        when(() => signUp(signUpParams)).thenAnswer(
          (_) async => const Right<Failure, SignUpResult>(
            SignUpResult(
              email: 'ana@finly.com',
              needsEmailVerification: true,
            ),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(signUpEvent),
      expect: () => [
        const AuthState.loading(),
        const AuthState.emailVerificationPending('ana@finly.com'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'is authenticated when sign-up returns a session',
      build: () {
        when(() => signUp(signUpParams)).thenAnswer(
          (_) async => const Right<Failure, SignUpResult>(
            SignUpResult(
              email: 'ana@finly.com',
              needsEmailVerification: false,
              user: user,
            ),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(signUpEvent),
      expect: () => [
        const AuthState.loading(),
        const AuthState.authenticated(user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits failed when the use case rejects the input',
      build: () {
        when(() => signUp(signUpParams)).thenAnswer(
          (_) async => const Left<Failure, SignUpResult>(
            ValidationFailure('weak_password'),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(signUpEvent),
      expect: () => [
        const AuthState.loading(),
        const AuthState.failed(ValidationFailure('weak_password')),
      ],
    );
  });

  group('sign out and navigation', () {
    blocTest<AuthBloc, AuthState>(
      'signs out and returns to unauthenticated',
      build: () {
        when(() => signOut(const SignOutParams()))
            .thenAnswer((_) async => const Right<Failure, void>(null));
        return buildBloc();
      },
      seed: () => const AuthState.authenticated(user),
      act: (bloc) => bloc.add(const SignOutRequested()),
      expect: () => [
        const AuthState.loading(user: user),
        const AuthState.unauthenticated(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'keeps the user when sign-out fails',
      build: () {
        when(() => signOut(const SignOutParams())).thenAnswer(
          (_) async =>
              const Left<Failure, void>(NetworkFailure('network_error')),
        );
        return buildBloc();
      },
      seed: () => const AuthState.authenticated(user),
      act: (bloc) => bloc.add(const SignOutRequested()),
      expect: () => [
        const AuthState.loading(user: user),
        const AuthState.failed(NetworkFailure('network_error'), user: user),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'leaves the confirm-e-mail screen',
      build: buildBloc,
      seed: () => const AuthState.emailVerificationPending('ana@finly.com'),
      act: (bloc) => bloc.add(const BackToSignInRequested()),
      expect: () => [const AuthState.unauthenticated()],
    );
  });
}