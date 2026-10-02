import 'package:equatable/equatable.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
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