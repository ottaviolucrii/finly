import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/dashboard/domain/entities/cash_flow_entry.dart';
import 'package:finly/features/dashboard/domain/entities/category_spend_entry.dart';
import 'package:finly/features/dashboard/domain/entities/monthly_flow_entry.dart';
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

  /// Income and expenses that already happened, per month and currency, from
  /// [from] (a month's first day, included) to [to] (excluded).
  Future<Either<Failure, List<MonthlyFlowEntry>>> getMonthlyFlow(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  });

  /// What was spent per category in [month] (its first day), per currency.
  /// Pending expenses count, like in the budgets.
  Future<Either<Failure, List<CategorySpendEntry>>> getCategorySpend(
    String workspaceId,
    DateTime month,
  );
}