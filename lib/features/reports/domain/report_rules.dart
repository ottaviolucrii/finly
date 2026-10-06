import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/dashboard/domain/chart_rules.dart';
import 'package:finly/features/dashboard/domain/entities/category_spend_entry.dart';
import 'package:finly/features/reports/domain/entities/monthly_report.dart';

/// How much [current] changed against [previous], in whole percent (rounded).
/// Null when there is nothing to compare with.
int? percentChange(int current, int previous) {
  if (previous <= 0) return null;
  return ((current - previous) * 100 / previous).round();
}

/// The spending table of one currency: the biggest categories first, each with
/// what it was the month before. Beyond [maxRows] categories, the smallest ones
/// are grouped into "Outras". A category that was spent only in the month
/// before does not appear.
List<CategoryChange> buildCategoryChanges(
  List<CategorySpendEntry> current,
  List<CategorySpendEntry> previous,
  List<CategoryEntity> categories,
  String currency, {
  int maxRows = 8,
}) {
  final currentById = <String?, int>{};
  for (final entry in current) {
    if (entry.currency != currency || entry.spentCents <= 0) continue;
    currentById[entry.categoryId] =
        (currentById[entry.categoryId] ?? 0) + entry.spentCents;
  }

  final previousById = <String?, int>{};
  for (final entry in previous) {
    if (entry.currency != currency || entry.spentCents <= 0) continue;
    previousById[entry.categoryId] =
        (previousById[entry.categoryId] ?? 0) + entry.spentCents;
  }

  final categoryById = {for (final c in categories) c.id: c};

  final rows = <CategoryChange>[
    for (final item in currentById.entries)
      () {
        final category = item.key == null ? null : categoryById[item.key];
        return CategoryChange(
          name: category?.name ?? uncategorizedName,
          colorHex: category?.colorHex ?? neutralColorHex,
          spentCents: item.value,
          previousCents: previousById[item.key] ?? 0,
        );
      }(),
  ]..sort((a, b) {
      final byAmount = b.spentCents.compareTo(a.spentCents);
      return byAmount != 0 ? byAmount : a.name.compareTo(b.name);
    });

  if (rows.length <= maxRows) return rows;

  final shown = rows.take(maxRows - 1).toList();
  final rest = rows.skip(maxRows - 1);
  return [
    ...shown,
    CategoryChange(
      name: otherCategoriesName,
      colorHex: neutralColorHex,
      spentCents: rest.fold<int>(0, (sum, row) => sum + row.spentCents),
      previousCents: rest.fold<int>(0, (sum, row) => sum + row.previousCents),
      isOther: true,
    ),
  ];
}