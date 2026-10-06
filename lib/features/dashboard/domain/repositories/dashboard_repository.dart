import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/dashboard/domain/entities/cash_flow_entry.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';

abstract class DashboardRepository {
  /// Incomes and expenses of [month] (its first day), failed and deleted
  /// ones excluded.
  Future<Either<Failure, List<CashFlowEntry>>> getCashFlow(
    String workspaceId,
    DateTime month,
  );

  /// Pending incomes and expenses from [from] (included) to [to] (excluded),
  /// oldest first.
  Future<Either<Failure, List<TransactionEntity>>> getUpcoming(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  });
}