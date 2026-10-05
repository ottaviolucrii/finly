import 'package:equatable/equatable.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';

/// Everything the budgets screen shows for one month.
class BudgetOverview extends Equatable {
  /// First day of the month.
  final DateTime month;

  /// Budgets in force this month, most used first.
  final List<BudgetProgress> items;

  /// All expense categories of the workspace (for the form).
  final List<CategoryEntity> expenseCategories;

  /// Expense categories with no budget in force this month.
  final List<CategoryEntity> withoutBudget;

  const BudgetOverview({
    required this.month,
    required this.items,
    required this.expenseCategories,
    required this.withoutBudget,
  });

  @override
  List<Object?> get props => [month, items, expenseCategories, withoutBudget];
}