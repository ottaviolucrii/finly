import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

abstract class TransactionRepository {
  /// Newest first, deleted ones excluded.
  Future<Either<Failure, List<TransactionEntity>>> getTransactions(
    String workspaceId, {
    int limit = 50,
  });

  Future<Either<Failure, TransactionEntity>> createTransaction({
    required String workspaceId,
    required String accountId,
    String? categoryId,
    required TransactionType type,
    required TransactionStatus status,
    required int amountCents,
    required String currency,
    required String description,
    required DateTime occurredAt,
  });

  /// The database only allows the changes of SRS BR-09 (for example
  /// pending to posted, but not posted to failed).
  Future<Either<Failure, void>> updateStatus(
    String transactionId,
    TransactionStatus status,
  );

  /// Soft delete: the row stays in the database and can be restored.
  Future<Either<Failure, void>> deleteTransaction(String transactionId);

  Future<Either<Failure, void>> restoreTransaction(String transactionId);
}