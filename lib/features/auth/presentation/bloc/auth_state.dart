import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';

enum AuthStatus {
  /// App just started; the stored session has not been checked yet.
  initial,
  unauthenticated,
  loading,
  authenticated,
  emailVerificationPending,
  failure,
}

class AuthState extends Equatable {
  final AuthStatus status;

  /// Set while signed in (also during sign-out and after a failed sign-out).
  final UserEntity? user;

  /// E-mail waiting for confirmation.
  final String? email;

  final Failure? failure;

  const AuthState._({
    required this.status,
    this.user,
    this.email,
    this.failure,
  });

  const AuthState.initial() : this._(status: AuthStatus.initial);

  const AuthState.unauthenticated()
      : this._(status: AuthStatus.unauthenticated);

  const AuthState.loading({UserEntity? user})
      : this._(status: AuthStatus.loading, user: user);

  const AuthState.authenticated(UserEntity user)
      : this._(status: AuthStatus.authenticated, user: user);

  const AuthState.emailVerificationPending(String email)
      : this._(status: AuthStatus.emailVerificationPending, email: email);

  const AuthState.failed(Failure failure, {UserEntity? user})
      : this._(status: AuthStatus.failure, failure: failure, user: user);

  bool get isLoading => status == AuthStatus.loading;

  @override
  List<Object?> get props => [status, user, email, failure];
}