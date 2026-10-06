import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/recurring/data/datasources/recurring_remote_data_source.dart';
import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:finly/features/recurring/domain/entities/recurring_entity.dart';
import 'package:finly/features/recurring/domain/repositories/recurring_repository.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

class RecurringRepositoryImpl implements RecurringRepository {
  final RecurringRemoteDataSource _remote;

  const RecurringRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<RecurringEntity>>> getRecurring(
    String workspaceId,
  ) {
    return _guard<List<RecurringEntity>>(
      () => _remote.getRecurring(workspaceId),
    );
  }

  @override
  Future<Either<Failure, RecurringEntity>> createRecurring({
    required String workspaceId,
    required String accountId,
    String? categoryId,
    required TransactionType type,
    required int amountCents,
    required String currency,
    required String description,
    required RecurrenceFrequency frequency,
    required int intervalCount,
    required DateTime startDate,
    DateTime? endDate,
  }) {
    return _guard<RecurringEntity>(
      () => _remote.createRecurring(
        workspaceId: workspaceId,
        accountId: accountId,
        categoryId: categoryId,
        type: type,
        amountCents: amountCents,
        currency: currency,
        description: description,
        frequency: frequency,
        intervalCount: intervalCount,
        startDate: startDate,
        endDate: endDate,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> updateRecurring({
    required String id,
    String? categoryId,
    required int amountCents,
    required String description,
    DateTime? endDate,
  }) {
    return _guard<void>(
      () => _remote.updateRecurring(
        id: id,
        categoryId: categoryId,
        amountCents: amountCents,
        description: description,
        endDate: endDate,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> deleteRecurring(String id) {
    return _guard<void>(() => _remote.deleteRecurring(id));
  }

  @override
  Future<Either<Failure, void>> setActive(String id, {required bool active}) {
    return _guard<void>(() => _remote.setActive(id, active: active));
  }

  @override
  Future<Either<Failure, int>> generateDue() {
    return _guard<int>(() => _remote.generateDue());
  }

  /// Runs [action]; exceptions become Left(Failure). Programming errors
  /// (Error) are mapped to an unknown_error failure and logged.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right<Failure, T>(await action());
    } catch (e) {
      return Left<Failure, T>(ErrorMapper.toFailure(e));
    }
  }
}