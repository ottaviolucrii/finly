import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/lock/domain/repositories/lock_repository.dart';

/// Checks the account password again, to unlock the app. Params: the password.
class VerifyPasswordUseCase implements UseCase<void, String> {
  final LockRepository _repository;

  const VerifyPasswordUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(String password) async {
    if (password.isEmpty) {
      return const Left(ValidationFailure('password_required'));
    }
    return _repository.verifyPassword(password);
  }
}