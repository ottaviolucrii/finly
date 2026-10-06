import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/accounts/domain/repositories/account_repository.dart';

/// Brings an archived account back. Params: the account id.
class RestoreAccountUseCase implements UseCase<void, String> {
  final AccountRepository _repository;

  const RestoreAccountUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(String accountId) async {
    if (accountId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_account'));
    }
    return _repository.restoreAccount(accountId);
  }
}