import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/repositories/transaction_repository.dart';

/// Marks a pending transaction as posted. Params: the transaction id.
class ConfirmTransactionUseCase implements UseCase<void, String> {
  final TransactionRepository _repository;

  const ConfirmTransactionUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(String transactionId) async {
    if (transactionId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_transaction'));
    }
    return _repository.updateStatus(transactionId, TransactionStatus.posted);
  }
}