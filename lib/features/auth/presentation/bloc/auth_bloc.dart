import 'package:finly/features/auth/domain/usecases/sign_in_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_out_use_case.dart';
import 'package:finly/features/auth/domain/usecases/sign_up_use_case.dart';
import 'package:finly/features/auth/presentation/bloc/auth_event.dart';
import 'package:finly/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SignInUseCase _signIn;
  final SignUpUseCase _signUp;
  final SignOutUseCase _signOut;

  AuthBloc({
    required SignInUseCase signIn,
    required SignUpUseCase signUp,
    required SignOutUseCase signOut,
  })  : _signIn = signIn,
        _signUp = signUp,
        _signOut = signOut,
        super(const AuthState.unauthenticated()) {
    on<SignInSubmitted>(_onSignInSubmitted);
    on<SignUpSubmitted>(_onSignUpSubmitted);
    on<SignOutRequested>(_onSignOutRequested);
    on<BackToSignInRequested>(
      (event, emit) => emit(const AuthState.unauthenticated()),
    );
  }

  Future<void> _onSignInSubmitted(
    SignInSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());
    final result = await _signIn(
      SignInParams(email: event.email, password: event.password),
    );
    emit(result.fold<AuthState>(
      (failure) => AuthState.failed(failure),
      (user) => AuthState.authenticated(user),
    ));
  }

  Future<void> _onSignUpSubmitted(
    SignUpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());
    final result = await _signUp(
      SignUpParams(
        fullName: event.fullName,
        email: event.email,
        password: event.password,
        acceptedTerms: event.acceptedTerms,
      ),
    );
    emit(result.fold<AuthState>(
      (failure) => AuthState.failed(failure),
      (data) {
        final user = data.user;
        if (data.needsEmailVerification || user == null) {
          return AuthState.emailVerificationPending(data.email);
        }
        return AuthState.authenticated(user);
      },
    ));
  }

  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    final previousUser = state.user;
    emit(AuthState.loading(user: previousUser));
    final result = await _signOut(SignOutParams(allDevices: event.allDevices));
    emit(result.fold<AuthState>(
      (failure) => AuthState.failed(failure, user: previousUser),
      (_) => const AuthState.unauthenticated(),
    ));
  }
}