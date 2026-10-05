import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/repositories/account_repository.dart';
import 'package:finly/features/budgets/domain/budget_rules.dart';
import 'package:finly/features/budgets/domain/entities/budget_overview.dart';
import 'package:finly/features/budgets/domain/usecases/get_budget_overview_use_case.dart';
import 'package:finly/features/dashboard/domain/dashboard_rules.dart';
import 'package:finly/features/dashboard/domain/entities/cash_flow_entry.dart';
import 'package:finly/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:finly/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';

class GetDashboardParams extends Equatable {
  final String workspaceId;

  /// "Now"; any time of the day.
  final DateTime today;

  const GetDashboardParams({required this.workspaceId, required this.today});

  @override
  List<Object?> get props => [workspaceId, today];
}

class GetDashboardUseCase
    implements UseCase<DashboardData, GetDashboardParams> {
  final AccountRepository _accounts;
  final DashboardRepository _dashboard;
  final GetBudgetOverviewUseCase _budgetOverview;

  const GetDashboardUseCase(
    this._accounts,
    this._dashboard,
    this._budgetOverview,
  );

  @override
  Future<Either<Failure, DashboardData>> call(GetDashboardParams params) async {
    final workspaceId = params.workspaceId;
    if (workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }

    final today = DateTime(
      params.today.year,
      params.today.month,
      params.today.day,
    );
    final month = monthStart(today);
    final from = DateTime(today.year, today.month, today.day - 30);
    final to = DateTime(today.year, today.month, today.day + 15);

    // The four loads do not depend on each other, so they run together.
    final (accountsResult, flowResult, upcomingResult, budgetsResult) = await (
      _accounts.getAccounts(workspaceId),
      _dashboard.getCashFlow(workspaceId, month),
      _dashboard.getUpcoming(workspaceId, from: from, to: to),
      _budgetOverview(
        GetBudgetOverviewParams(workspaceId: workspaceId, month: month),
      ),
    ).wait;

    Failure? failure;
    var accounts = const <AccountEntity>[];
    var entries = const <CashFlowEntry>[];
    var upcoming = const <TransactionEntity>[];
    BudgetOverview? overview;

    accountsResult.fold((f) {
      failure ??= f;
    }, (value) {
      accounts = value;
    });
    flowResult.fold((f) {
      failure ??= f;
    }, (value) {
      entries = value;
    });
    upcomingResult.fold((f) {
      failure ??= f;
    }, (value) {
      upcoming = value;
    });
    budgetsResult.fold((f) {
      failure ??= f;
    }, (value) {
      overview = value;
    });

    final problem = failure;
    if (problem != null) return Left<Failure, DashboardData>(problem);

    final sortedUpcoming = [...upcoming]
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    return Right<Failure, DashboardData>(
      DashboardData(
        month: month,
        accountCount: accounts.length,
        balances: totalsByCurrency(accounts),
        flows: aggregateFlow(entries),
        budgets: (overview?.items ?? const []).take(3).toList(),
        upcoming: sortedUpcoming.take(6).toList(),
      ),
    );
  }
}