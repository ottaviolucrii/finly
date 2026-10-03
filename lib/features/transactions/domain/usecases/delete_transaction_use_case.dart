import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/transactions/domain/repositories/transaction_repository.dart';

/// Soft-deletes a transaction. Params: the transaction id.
class DeleteTransactionUseCase implements UseCase<void, String> {
  final TransactionRepository _repository;

  const DeleteTransactionUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(String transactionId) async {
    if (transactionId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_transaction'));
    }
    return _repository.deleteTransaction(transactionId);
  }
}