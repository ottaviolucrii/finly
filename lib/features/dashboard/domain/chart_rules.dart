import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/dashboard/domain/entities/category_spend_entry.dart';
import 'package:finly/features/dashboard/domain/entities/dashboard_charts.dart';
import 'package:finly/features/dashboard/domain/entities/monthly_flow_entry.dart';

const String otherCategoriesName = 'Outras';
const String uncategorizedName = 'Sem categoria';

/// The brand gray, for slices that have no category colour.
const String neutralColorHex = '#A8A8A8';

/// The first day of each of the last [count] months, oldest first, the last
/// one being the month of [today].
List<DateTime> lastMonths(DateTime today, {int count = 6}) {
  return [
    for (var i = count - 1; i >= 0; i--) DateTime(today.year, today.month - i),
  ];
}

/// One point per month of [months] for [currency]. Months with no entries
/// come out as zeros, so the chart always has the same number of bars.
List<MonthlyFlowPoint> buildMonthlyPoints(
  List<MonthlyFlowEntry> entries,
  List<DateTime> months,
  String currency,
) {
  return [
    for (final month in months)
      () {
        var income = 0;
        var expense = 0;
        for (final entry in entries) {
          if (entry.currency != currency) continue;
          if (entry.month.year != month.year || entry.month.month != month.month) {
            continue;
          }
          income += entry.incomeCents;
          expense += entry.expenseCents;
        }
        return MonthlyFlowPoint(
          month: month,
          incomeCents: income,
          expenseCents: expense,
        );
      }(),
  ];
}

/// The spending slices of one currency, biggest first. When there are more
/// than [maxSlices] categories, the smallest ones are grouped into "Outras"
/// so the donut stays readable.
List<CategorySlice> buildCategorySlices(
  List<CategorySpendEntry> entries,
  List<CategoryEntity> categories,
  String currency, {
  int maxSlices = 5,
}) {
  final spentById = <String?, int>{};
  for (final entry in entries) {
    if (entry.currency != currency || entry.spentCents <= 0) continue;
    spentById[entry.categoryId] =
        (spentById[entry.categoryId] ?? 0) + entry.spentCents;
  }

  final categoryById = {for (final c in categories) c.id: c};

  final slices = <CategorySlice>[
    for (final item in spentById.entries)
      () {
        final category = item.key == null ? null : categoryById[item.key];
        return CategorySlice(
          name: category?.name ?? uncategorizedName,
          colorHex: category?.colorHex ?? neutralColorHex,
          spentCents: item.value,
        );
      }(),
  ]..sort((a, b) {
      final byAmount = b.spentCents.compareTo(a.spentCents);
      return byAmount != 0 ? byAmount : a.name.compareTo(b.name);
    });

  if (slices.length <= maxSlices) return slices;

  final shown = slices.take(maxSlices - 1).toList();
  final rest = slices.skip(maxSlices - 1);
  final restTotal = rest.fold<int>(0, (sum, slice) => sum + slice.spentCents);
  return [
    ...shown,
    CategorySlice(
      name: otherCategoriesName,
      colorHex: neutralColorHex,
      spentCents: restTotal,
      isOther: true,
    ),
  ];
}