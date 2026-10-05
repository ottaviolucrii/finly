import 'package:equatable/equatable.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Sent once when the app starts: restores the stored session, if any.
class AuthStarted extends AuthEvent {
  const AuthStarted();
}

/// Reloads the signed-in user (for example after a workspace was created).
class UserRefreshRequested extends AuthEvent {
  const UserRefreshRequested();
}

/// Replaces the signed-in user with one that is already loaded (for example
/// the user returned by a workspace switch), with no extra network call.
class UserReplaced extends AuthEvent {
  final UserEntity user;

  const UserReplaced(this.user);

  @override
  List<Object?> get props => [user];
}

class SignInSubmitted extends AuthEvent {
  final String email;
  final String password;

  const SignInSubmitted({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class SignUpSubmitted extends AuthEvent {
  final String fullName;
  final String email;
  final String password;
  final bool acceptedTerms;

  const SignUpSubmitted({
    required this.fullName,
    required this.email,
    required this.password,
    required this.acceptedTerms,
  });

  @override
  List<Object?> get props => [fullName, email, password, acceptedTerms];
}

class SignOutRequested extends AuthEvent {
  final bool allDevices;

  const SignOutRequested({this.allDevices = false});

  @override
  List<Object?> get props => [allDevices];
}

/// Leaves the "confirm your e-mail" screen and returns to sign in.
class BackToSignInRequested extends AuthEvent {
  const BackToSignInRequested();
}