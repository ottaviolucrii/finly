import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/alerts/domain/alert_rules.dart';
import 'package:finly/features/alerts/domain/entities/app_alert.dart';
import 'package:finly/features/budgets/domain/entities/budget_overview.dart';
import 'package:finly/features/budgets/domain/usecases/get_budget_overview_use_case.dart';
import 'package:finly/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';

class GetAlertsParams extends Equatable {
  final String workspaceId;

  /// "Now"; any time of the day.
  final DateTime today;

  const GetAlertsParams({required this.workspaceId, required this.today});

  @override
  List<Object?> get props => [workspaceId, today];
}

/// Everything the user should look at today, most urgent first: budgets at 80%
/// or more, and pending bills that are overdue or due in the next days.
class GetAlertsUseCase implements UseCase<List<AppAlert>, GetAlertsParams> {
  /// How far back an overdue bill is still reported.
  static const lookBackDays = 60;

  final GetBudgetOverviewUseCase _budgets;
  final DashboardRepository _dashboard;

  const GetAlertsUseCase(this._budgets, this._dashboard);

  @override
  Future<Either<Failure, List<AppAlert>>> call(GetAlertsParams params) async {
    final workspaceId = params.workspaceId;
    if (workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }

    final today = params.today;
    final from = DateTime(today.year, today.month, today.day - lookBackDays);
    // The end is excluded, so one day past the last "due soon" day.
    final to = DateTime(today.year, today.month, today.day + dueSoonDays + 1);

    // The two loads do not depend on each other, so they run together.
    final (overviewResult, upcomingResult) = await (
      _budgets(GetBudgetOverviewParams(workspaceId: workspaceId, month: today)),
      _dashboard.getUpcoming(workspaceId, from: from, to: to),
    ).wait;

    Failure? failure;
    BudgetOverview? overview;
    var upcoming = const <TransactionEntity>[];

    overviewResult.fold((f) {
      failure ??= f;
    }, (value) {
      overview = value;
    });
    upcomingResult.fold((f) {
      failure ??= f;
    }, (value) {
      upcoming = value;
    });

    final problem = failure;
    if (problem != null) return Left<Failure, List<AppAlert>>(problem);

    return Right<Failure, List<AppAlert>>(
      sortAlerts([
        ...budgetAlerts(overview?.items ?? const []),
        ...billAlerts(upcoming, today),
      ]),
    );
  }
}