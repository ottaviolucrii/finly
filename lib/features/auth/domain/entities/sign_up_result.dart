import 'package:equatable/equatable.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';

/// Outcome of a successful sign-up.
class SignUpResult extends Equatable {
  final String email;

  /// True when the user must confirm the e-mail before getting a session.
  final bool needsEmailVerification;

  /// Null while verification is pending (no session exists yet).
  final UserEntity? user;

  const SignUpResult({
    required this.email,
    required this.needsEmailVerification,
    this.user,
  });

  @override
  List<Object?> get props => [email, needsEmailVerification, user];
}