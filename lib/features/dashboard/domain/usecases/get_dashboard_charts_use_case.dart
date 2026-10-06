import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/repositories/category_repository.dart';
import 'package:finly/features/dashboard/domain/chart_rules.dart';
import 'package:finly/features/dashboard/domain/dashboard_rules.dart';
import 'package:finly/features/dashboard/domain/entities/category_spend_entry.dart';
import 'package:finly/features/dashboard/domain/entities/dashboard_charts.dart';
import 'package:finly/features/dashboard/domain/entities/monthly_flow_entry.dart';
import 'package:finly/features/dashboard/domain/repositories/dashboard_repository.dart';

class GetDashboardChartsParams extends Equatable {
  final String workspaceId;

  /// "Now"; any time of the day.
  final DateTime today;

  const GetDashboardChartsParams({
    required this.workspaceId,
    required this.today,
  });

  @override
  List<Object?> get props => [workspaceId, today];
}

/// The data of the two dashboard charts: income and expenses of the last six
/// months, and this month's spending by category.
class GetDashboardChartsUseCase
    implements UseCase<DashboardCharts, GetDashboardChartsParams> {
  final DashboardRepository _dashboard;
  final CategoryRepository _categories;

  const GetDashboardChartsUseCase(this._dashboard, this._categories);

  @override
  Future<Either<Failure, DashboardCharts>> call(
    GetDashboardChartsParams params,
  ) async {
    final workspaceId = params.workspaceId;
    if (workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }

    final today = params.today;
    final months = lastMonths(today);
    final currentMonth = months.last;
    final end = DateTime(today.year, today.month + 1);

    // The three loads do not depend on each other, so they run together.
    final (flowResult, spendResult, categoriesResult) = await (
      _dashboard.getMonthlyFlow(workspaceId, from: months.first, to: end),
      _dashboard.getCategorySpend(workspaceId, currentMonth),
      // Archived categories too: their old spending keeps its name.
      _categories.getAllCategories(workspaceId),
    ).wait;

    Failure? failure;
    var flows = const <MonthlyFlowEntry>[];
    var spends = const <CategorySpendEntry>[];
    var categories = const <CategoryEntity>[];

    flowResult.fold((f) {
      failure ??= f;
    }, (value) {
      flows = value;
    });
    spendResult.fold((f) {
      failure ??= f;
    }, (value) {
      spends = value;
    });
    categoriesResult.fold((f) {
      failure ??= f;
    }, (value) {
      categories = value;
    });

    final problem = failure;
    if (problem != null) return Left<Failure, DashboardCharts>(problem);

    final currencies = sortCurrencies([
      ...flows.map((entry) => entry.currency),
      ...spends.map((entry) => entry.currency),
    ]);

    return Right<Failure, DashboardCharts>(
      DashboardCharts(
        month: currentMonth,
        byCurrency: [
          for (final currency in currencies)
            CurrencyCharts(
              currency: currency,
              months: buildMonthlyPoints(flows, months, currency),
              categories: buildCategorySlices(spends, categories, currency),
            ),
        ],
      ),
    );
  }
}