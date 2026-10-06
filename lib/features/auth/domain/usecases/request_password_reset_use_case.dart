import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/core/utils/validators.dart';
import 'package:finly/features/auth/domain/repositories/auth_repository.dart';

/// Asks for a one-time code by e-mail to reset the password. Params: the
/// e-mail.
class RequestPasswordResetUseCase implements UseCase<void, String> {
  final AuthRepository _repository;

  const RequestPasswordResetUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(String email) async {
    final trimmed = email.trim();
    if (!Validators.isValidEmail(trimmed)) {
      return const Left(ValidationFailure('invalid_email'));
    }
    return _repository.requestPasswordReset(email: trimmed);
  }
}