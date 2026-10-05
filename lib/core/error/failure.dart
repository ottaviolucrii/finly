import 'package:equatable/equatable.dart';

/// Base type for every error the domain layer can return.
///
/// [message] is a stable code such as `invalid_email`, not display text.
/// The UI translates the code, so wording can change without touching logic.
abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

/// Server or database problem.
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// Authentication problem (wrong password, unverified e-mail, no session).
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// Input rejected before or by the server (bad tax id, weak password).
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// No connection, timeout.
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// The user is not allowed to do this (RLS / ownership).
class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}

/// Something already exists (duplicate).
class ConflictFailure extends Failure {
  const ConflictFailure(super.message);
}

/// A business rule enforced by the database refused the operation.
class RuleFailure extends Failure {
  const RuleFailure(super.message);
}