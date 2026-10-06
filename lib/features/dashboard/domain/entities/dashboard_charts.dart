import 'package:equatable/equatable.dart';

/// One bar group of the cash flow chart.
class MonthlyFlowPoint extends Equatable {
  /// First day of the month.
  final DateTime month;
  final int incomeCents;
  final int expenseCents;

  const MonthlyFlowPoint({
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
  });

  bool get isEmpty => incomeCents == 0 && expenseCents == 0;

  @override
  List<Object?> get props => [month, incomeCents, expenseCents];
}

/// One slice of the spending donut.
class CategorySlice extends Equatable {
  final String name;
  final String colorHex;
  final int spentCents;

  /// True for the slice that groups the smallest categories.
  final bool isOther;

  const CategorySlice({
    required this.name,
    required this.colorHex,
    required this.spentCents,
    this.isOther = false,
  });

  @override
  List<Object?> get props => [name, colorHex, spentCents, isOther];
}

/// The charts of one currency.
class CurrencyCharts extends Equatable {
  final String currency;

  /// The last months, oldest first, with zeros where nothing happened.
  final List<MonthlyFlowPoint> months;

  /// This month's spending, biggest first.
  final List<CategorySlice> categories;

  const CurrencyCharts({
    required this.currency,
    required this.months,
    required this.categories,
  });

  bool get hasFlow => months.any((point) => !point.isEmpty);

  int get categoryTotalCents =>
      categories.fold<int>(0, (sum, slice) => sum + slice.spentCents);

  @override
  List<Object?> get props => [currency, months, categories];
}

/// Everything the dashboard charts show for one workspace.
class DashboardCharts extends Equatable {
  /// First day of the current month.
  final DateTime month;
  final List<CurrencyCharts> byCurrency;

  const DashboardCharts({required this.month, required this.byCurrency});

  bool get isEmpty => byCurrency.isEmpty;

  @override
  List<Object?> get props => [month, byCurrency];
}