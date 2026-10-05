import 'package:finly/features/budgets/domain/entities/budget_entity.dart';

/// The first day of the month of [date], at midnight.
DateTime monthStart(DateTime date) => DateTime(date.year, date.month);

/// Moves a month by [delta] months; the year rolls over by itself.
DateTime addMonths(DateTime month, int delta) =>
    DateTime(month.year, month.month + delta);

/// "2026-03-05", the format the database uses for dates.
String isoDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// The budget in force for [categoryId] in [month]: the latest version that
/// starts on or before that month. Null when there is none, or when that
/// latest version is an end marker (limit 0 = "no budget from here on").
BudgetEntity? activeBudget(
  List<BudgetEntity> versions,
  String categoryId,
  DateTime month,
) {
  final target = monthStart(month);
  BudgetEntity? best;
  for (final version in versions) {
    if (version.categoryId != categoryId) continue;
    if (monthStart(version.effectiveFrom).isAfter(target)) continue;
    if (best == null || version.effectiveFrom.isAfter(best.effectiveFrom)) {
      best = version;
    }
  }
  if (best != null && best.limitCents == 0) return null;
  return best;
}