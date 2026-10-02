import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/accounts/domain/repositories/account_repository.dart';

/// Params: the account id.
class ArchiveAccountUseCase implements UseCase<void, String> {
  final AccountRepository _repository;

  const ArchiveAccountUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(String accountId) async {
    if (accountId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_account'));
    }
    return _repository.archiveAccount(accountId);
  }
}