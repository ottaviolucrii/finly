import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/auth/domain/entities/tax_id_type.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
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
  late MockGetCurrentUser getCurrentUser;

  const withoutWorkspace = UserEntity(
    id: 'u1',
    fullName: 'Ana Teste',
    email: 'ana@finly.com',
    workspaces: [],
  );
  const workspace = WorkspaceEntity(
    id: 'w1',
    ownerId: 'u1',
    name: 'Pessoal',
    taxId: '52998224725',
    taxIdType: TaxIdType.cpf,
    type: WorkspaceType.personal,
  );
  const withWorkspace = UserEntity(
    id: 'u1',
    fullName: 'Ana Teste',
    email: 'ana@finly.com',
    workspaces: [workspace],
    activeWorkspaceId: 'w1',
  );

  setUp(() => getCurrentUser = MockGetCurrentUser());

  AuthBloc buildBloc() => AuthBloc(
        signIn: MockSignIn(),
        signUp: MockSignUp(),
        signOut: MockSignOut(),
        getCurrentUser: getCurrentUser,
      );

  blocTest<AuthBloc, AuthState>(
    'reloads the user after a workspace was created',
    build: () {
      when(() => getCurrentUser(const NoParams())).thenAnswer(
        (_) async => const Right<Failure, UserEntity?>(withWorkspace),
      );
      return buildBloc();
    },
    seed: () => const AuthState.authenticated(withoutWorkspace),
    act: (bloc) => bloc.add(const UserRefreshRequested()),
    expect: () => [const AuthState.authenticated(withWorkspace)],
  );

  blocTest<AuthBloc, AuthState>(
    'keeps the current state when the reload fails',
    build: () {
      when(() => getCurrentUser(const NoParams())).thenAnswer(
        (_) async => const Left<Failure, UserEntity?>(
          NetworkFailure('network_error'),
        ),
      );
      return buildBloc();
    },
    seed: () => const AuthState.authenticated(withoutWorkspace),
    act: (bloc) => bloc.add(const UserRefreshRequested()),
    expect: () => <AuthState>[],
  );

  blocTest<AuthBloc, AuthState>(
    'keeps the current state when there is no user to reload',
    build: () {
      when(() => getCurrentUser(const NoParams())).thenAnswer(
        (_) async => const Right<Failure, UserEntity?>(null),
      );
      return buildBloc();
    },
    seed: () => const AuthState.authenticated(withoutWorkspace),
    act: (bloc) => bloc.add(const UserRefreshRequested()),
    expect: () => <AuthState>[],
  );
}