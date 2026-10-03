import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/repositories/transaction_repository.dart';

/// Params: the workspace id.
class GetTransactionsUseCase
    implements UseCase<List<TransactionEntity>, String> {
  final TransactionRepository _repository;

  const GetTransactionsUseCase(this._repository);

  @override
  Future<Either<Failure, List<TransactionEntity>>> call(
    String workspaceId,
  ) async {
    if (workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }
    return _repository.getTransactions(workspaceId);
  }
}