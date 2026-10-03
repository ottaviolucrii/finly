import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/transactions/domain/repositories/transaction_repository.dart';

/// Brings a soft-deleted transaction back (the "undo" of a delete).
/// Params: the transaction id.
class RestoreTransactionUseCase implements UseCase<void, String> {
  final TransactionRepository _repository;

  const RestoreTransactionUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(String transactionId) async {
    if (transactionId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_transaction'));
    }
    return _repository.restoreTransaction(transactionId);
  }
}