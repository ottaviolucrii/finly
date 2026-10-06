import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/data/datasources/transaction_remote_data_source.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_filter.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionRemoteDataSource _remote;

  const TransactionRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<TransactionEntity>>> getTransactions(
    String workspaceId, {
    int limit = 20,
    int offset = 0,
    TransactionFilter filter = const TransactionFilter(),
  }) {
    return _guard<List<TransactionEntity>>(
      () => _remote.getTransactions(
        workspaceId,
        limit: limit,
        offset: offset,
        filter: filter,
      ),
    );
  }

  @override
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
  }) {
    return _guard<TransactionEntity>(
      () => _remote.createTransaction(
        workspaceId: workspaceId,
        accountId: accountId,
        categoryId: categoryId,
        type: type,
        status: status,
        amountCents: amountCents,
        currency: currency,
        description: description,
        occurredAt: occurredAt,
      ),
    );
  }

  @override
  Future<Either<Failure, TransactionEntity>> updateTransaction({
    required String transactionId,
    String? categoryId,
    required int amountCents,
    required String description,
    required DateTime occurredAt,
    required TransactionStatus status,
  }) {
    return _guard<TransactionEntity>(
      () => _remote.updateTransaction(
        transactionId: transactionId,
        categoryId: categoryId,
        amountCents: amountCents,
        description: description,
        occurredAt: occurredAt,
        status: status,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> updateStatus(
    String transactionId,
    TransactionStatus status,
  ) {
    return _guard<void>(() => _remote.updateStatus(transactionId, status));
  }

  @override
  Future<Either<Failure, void>> deleteTransaction(String transactionId) {
    return _guard<void>(
      () => _remote.setDeleted(transactionId, deleted: true),
    );
  }

  @override
  Future<Either<Failure, void>> restoreTransaction(String transactionId) {
    return _guard<void>(
      () => _remote.setDeleted(transactionId, deleted: false),
    );
  }

  /// Runs [action]; exceptions become Left(Failure). Programming errors
  /// (Error, not Exception) are not caught on purpose.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right<Failure, T>(await action());
    } on Exception catch (e) {
      return Left<Failure, T>(ErrorMapper.toFailure(e));
    }
  }
}