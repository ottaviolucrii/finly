import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:finly/features/dashboard/domain/entities/cash_flow_entry.dart';
import 'package:finly/features/dashboard/domain/entities/category_spend_entry.dart';
import 'package:finly/features/dashboard/domain/entities/monthly_flow_entry.dart';
import 'package:finly/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDataSource _remote;

  const DashboardRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<CashFlowEntry>>> getCashFlow(
    String workspaceId,
    DateTime month,
  ) {
    return _guard<List<CashFlowEntry>>(
      () => _remote.getCashFlow(workspaceId, month),
    );
  }

  @override
  Future<Either<Failure, List<TransactionEntity>>> getUpcoming(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) {
    return _guard<List<TransactionEntity>>(
      () => _remote.getUpcoming(workspaceId, from: from, to: to),
    );
  }

  @override
  Future<Either<Failure, List<MonthlyFlowEntry>>> getMonthlyFlow(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) {
    return _guard<List<MonthlyFlowEntry>>(
      () => _remote.getMonthlyFlow(workspaceId, from: from, to: to),
    );
  }

  @override
  Future<Either<Failure, List<CategorySpendEntry>>> getCategorySpend(
    String workspaceId,
    DateTime month,
  ) {
    return _guard<List<CategorySpendEntry>>(
      () => _remote.getCategorySpend(workspaceId, month),
    );
  }

  @override
  Future<Either<Failure, List<TransactionEntity>>> getTopExpenses(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
    required String currency,
    required int limit,
  }) {
    return _guard<List<TransactionEntity>>(
      () => _remote.getTopExpenses(
        workspaceId,
        from: from,
        to: to,
        currency: currency,
        limit: limit,
      ),
    );
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