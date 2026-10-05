import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:finly/features/budgets/domain/entities/category_spend.dart';

abstract class BudgetRepository {
  /// Every version of every budget of the workspace.
  Future<Either<Failure, List<BudgetEntity>>> getBudgets(String workspaceId);

  /// Spending per category and currency in [month] (its first day).
  Future<Either<Failure, List<CategorySpend>>> getMonthlySpend(
    String workspaceId,
    DateTime month,
  );

  /// Saves the limit from [effectiveFrom] on. Saving the same category and
  /// month again replaces that version.
  Future<Either<Failure, BudgetEntity>> saveBudget({
    required String workspaceId,
    required String categoryId,
    required DateTime effectiveFrom,
    required int limitCents,
    required String currency,
  });

  Future<Either<Failure, void>> deleteBudget(String budgetId);
}