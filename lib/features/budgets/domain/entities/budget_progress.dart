import 'package:equatable/equatable.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';

enum BudgetLevel { normal, warning, over }

/// A budget together with what was spent against it in one month.
class BudgetProgress extends Equatable {
  final BudgetEntity budget;
  final CategoryEntity category;
  final int spentCents;

  const BudgetProgress({
    required this.budget,
    required this.category,
    required this.spentCents,
  });

  String get currency => budget.currency;
  int get limitCents => budget.limitCents;

  /// Negative when the budget was exceeded.
  int get remainingCents => limitCents - spentCents;

  /// For the progress bar only: money is never calculated with this number.
  double get ratio => limitCents <= 0 ? 0 : spentCents / limitCents;

  /// Under 80% is normal, 80% to 100% a warning, above 100% over the budget
  /// (SRS FR-B02).
  BudgetLevel get level {
    if (spentCents > limitCents) return BudgetLevel.over;
    if (ratio >= 0.8) return BudgetLevel.warning;
    return BudgetLevel.normal;
  }

  Money get spent => Money(spentCents, currency);
  Money get limit => Money(limitCents, currency);
  Money get remaining => Money(remainingCents, currency);

  @override
  List<Object?> get props => [budget, category, spentCents];
}