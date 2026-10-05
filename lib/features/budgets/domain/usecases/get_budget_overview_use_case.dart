import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/budgets/domain/budget_rules.dart';
import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:finly/features/budgets/domain/entities/budget_overview.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/budgets/domain/entities/category_spend.dart';
import 'package:finly/features/budgets/domain/repositories/budget_repository.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/domain/repositories/category_repository.dart';

class GetBudgetOverviewParams extends Equatable {
  final String workspaceId;

  /// Any date inside the month.
  final DateTime month;

  const GetBudgetOverviewParams({
    required this.workspaceId,
    required this.month,
  });

  @override
  List<Object?> get props => [workspaceId, month];
}

class GetBudgetOverviewUseCase
    implements UseCase<BudgetOverview, GetBudgetOverviewParams> {
  final BudgetRepository _budgets;
  final CategoryRepository _categories;

  const GetBudgetOverviewUseCase(this._budgets, this._categories);

  @override
  Future<Either<Failure, BudgetOverview>> call(
    GetBudgetOverviewParams params,
  ) async {
    if (params.workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }
    final month = monthStart(params.month);

    final budgetsResult = await _budgets.getBudgets(params.workspaceId);
    final spendResult = await _budgets.getMonthlySpend(params.workspaceId, month);
    final categoriesResult = await _categories.getCategories(params.workspaceId);

    Failure? failure;
    var budgets = const <BudgetEntity>[];
    var spend = const <CategorySpend>[];
    var categories = const <CategoryEntity>[];

    budgetsResult.fold((f) {
      failure ??= f;
    }, (value) {
      budgets = value;
    });
    spendResult.fold((f) {
      failure ??= f;
    }, (value) {
      spend = value;
    });
    categoriesResult.fold((f) {
      failure ??= f;
    }, (value) {
      categories = value;
    });

    final problem = failure;
    if (problem != null) return Left<Failure, BudgetOverview>(problem);

    final expenseCategories = categories
        .where((category) => category.kind == CategoryKind.expense)
        .toList();

    final items = <BudgetProgress>[];
    final withoutBudget = <CategoryEntity>[];
    for (final category in expenseCategories) {
      final budget = activeBudget(budgets, category.id, month);
      if (budget == null) {
        withoutBudget.add(category);
        continue;
      }

      // Spending in another currency does not count against this budget.
      var spent = 0;
      for (final row in spend) {
        if (row.categoryId == category.id && row.currency == budget.currency) {
          spent += row.spentCents;
        }
      }
      items.add(
        BudgetProgress(budget: budget, category: category, spentCents: spent),
      );
    }

    // The riskiest budgets first.
    items.sort((a, b) {
      final byUsage = b.ratio.compareTo(a.ratio);
      return byUsage != 0 ? byUsage : a.category.name.compareTo(b.category.name);
    });

    return Right<Failure, BudgetOverview>(
      BudgetOverview(
        month: month,
        items: items,
        expenseCategories: expenseCategories,
        withoutBudget: withoutBudget,
      ),
    );
  }
}