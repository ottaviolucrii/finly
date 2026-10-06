import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/repositories/category_repository.dart';
import 'package:finly/features/dashboard/domain/dashboard_rules.dart';
import 'package:finly/features/dashboard/domain/entities/category_spend_entry.dart';
import 'package:finly/features/dashboard/domain/entities/monthly_flow_entry.dart';
import 'package:finly/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:finly/features/reports/domain/entities/monthly_report.dart';
import 'package:finly/features/reports/domain/report_rules.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';

class GetMonthlyReportParams extends Equatable {
  final String workspaceId;

  /// Any day of the month of the report.
  final DateTime month;

  const GetMonthlyReportParams({required this.workspaceId, required this.month});

  @override
  List<Object?> get props => [workspaceId, month];
}

/// The report of one month, compared with the month before. It reads the same
/// views as the dashboard charts, plus the biggest expenses.
class GetMonthlyReportUseCase
    implements UseCase<MonthlyReport, GetMonthlyReportParams> {
  /// How many "biggest expenses" the report lists per currency.
  static const topExpensesCount = 5;

  final DashboardRepository _dashboard;
  final CategoryRepository _categories;

  const GetMonthlyReportUseCase(this._dashboard, this._categories);

  @override
  Future<Either<Failure, MonthlyReport>> call(
    GetMonthlyReportParams params,
  ) async {
    final workspaceId = params.workspaceId;
    if (workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }

    final month = DateTime(params.month.year, params.month.month);
    final previous = DateTime(month.year, month.month - 1);
    final next = DateTime(month.year, month.month + 1);

    final (flowResult, spendResult, previousSpendResult, categoriesResult) =
        await (
      _dashboard.getMonthlyFlow(workspaceId, from: previous, to: next),
      _dashboard.getCategorySpend(workspaceId, month),
      _dashboard.getCategorySpend(workspaceId, previous),
      // Archived categories too: their spending keeps its name.
      _categories.getAllCategories(workspaceId),
    ).wait;

    Failure? failure;
    var flows = const <MonthlyFlowEntry>[];
    var spends = const <CategorySpendEntry>[];
    var previousSpends = const <CategorySpendEntry>[];
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
    previousSpendResult.fold((f) {
      failure ??= f;
    }, (value) {
      previousSpends = value;
    });
    categoriesResult.fold((f) {
      failure ??= f;
    }, (value) {
      categories = value;
    });

    final problem = failure;
    if (problem != null) return Left<Failure, MonthlyReport>(problem);

    // Only the currencies that have something this month.
    final currencies = sortCurrencies([
      ...flows
          .where((e) => _sameMonth(e.month, month))
          .map((e) => e.currency),
      ...spends.map((e) => e.currency),
    ]);

    final reports = <CurrencyReport>[];
    for (final currency in currencies) {
      final top = await _dashboard.getTopExpenses(
        workspaceId,
        from: month,
        to: next,
        currency: currency,
        limit: topExpensesCount,
      );

      Failure? topFailure;
      var topExpenses = const <TransactionEntity>[];
      top.fold((f) {
        topFailure = f;
      }, (value) {
        topExpenses = value;
      });
      final topProblem = topFailure;
      if (topProblem != null) return Left<Failure, MonthlyReport>(topProblem);

      int sum(DateTime m, int Function(MonthlyFlowEntry) pick) => flows
          .where((e) => e.currency == currency && _sameMonth(e.month, m))
          .fold<int>(0, (total, e) => total + pick(e));

      reports.add(
        CurrencyReport(
          currency: currency,
          incomeCents: sum(month, (e) => e.incomeCents),
          expenseCents: sum(month, (e) => e.expenseCents),
          previousIncomeCents: sum(previous, (e) => e.incomeCents),
          previousExpenseCents: sum(previous, (e) => e.expenseCents),
          categories: buildCategoryChanges(
            spends,
            previousSpends,
            categories,
            currency,
          ),
          topExpenses: topExpenses,
        ),
      );
    }

    return Right<Failure, MonthlyReport>(
      MonthlyReport(month: month, byCurrency: reports),
    );
  }

  static bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;
}