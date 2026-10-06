import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/repositories/account_repository.dart';

/// Params: the workspace id.
class GetArchivedAccountsUseCase
    implements UseCase<List<AccountEntity>, String> {
  final AccountRepository _repository;

  const GetArchivedAccountsUseCase(this._repository);

  @override
  Future<Either<Failure, List<AccountEntity>>> call(String workspaceId) async {
    if (workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }
    return _repository.getArchivedAccounts(workspaceId);
  }
}