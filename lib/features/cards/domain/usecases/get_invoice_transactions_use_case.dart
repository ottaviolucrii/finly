import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/cards/domain/repositories/card_repository.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';

/// Params: the invoice id.
class GetInvoiceTransactionsUseCase
    implements UseCase<List<TransactionEntity>, String> {
  final CardRepository _repository;

  const GetInvoiceTransactionsUseCase(this._repository);

  @override
  Future<Either<Failure, List<TransactionEntity>>> call(
    String invoiceId,
  ) async {
    if (invoiceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_invoice'));
    }
    return _repository.getInvoiceTransactions(invoiceId);
  }
}