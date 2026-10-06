import 'package:equatable/equatable.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';

/// One row of the "spending by category" table.
class CategoryChange extends Equatable {
  final String name;
  final String colorHex;

  /// Spent in the month of the report.
  final int spentCents;

  /// Spent on the same category in the month before (0 when nothing).
  final int previousCents;

  /// True for the row that groups the smallest categories.
  final bool isOther;

  const CategoryChange({
    required this.name,
    required this.colorHex,
    required this.spentCents,
    required this.previousCents,
    this.isOther = false,
  });

  @override
  List<Object?> get props =>
      [name, colorHex, spentCents, previousCents, isOther];
}

/// The report of one month in one currency.
class CurrencyReport extends Equatable {
  final String currency;

  /// What already happened in the month (posted only).
  final int incomeCents;
  final int expenseCents;

  /// The same, for the month before.
  final int previousIncomeCents;
  final int previousExpenseCents;

  /// Spending by category, biggest first (pending included).
  final List<CategoryChange> categories;

  /// The biggest expenses of the month, biggest first.
  final List<TransactionEntity> topExpenses;

  const CurrencyReport({
    required this.currency,
    required this.incomeCents,
    required this.expenseCents,
    required this.previousIncomeCents,
    required this.previousExpenseCents,
    required this.categories,
    required this.topExpenses,
  });

  int get netCents => incomeCents - expenseCents;
  int get previousNetCents => previousIncomeCents - previousExpenseCents;

  int get categoryTotalCents =>
      categories.fold<int>(0, (sum, row) => sum + row.spentCents);

  @override
  List<Object?> get props => [
        currency,
        incomeCents,
        expenseCents,
        previousIncomeCents,
        previousExpenseCents,
        categories,
        topExpenses,
      ];
}

/// Everything the report screen shows for one workspace and month.
class MonthlyReport extends Equatable {
  /// First day of the month.
  final DateTime month;
  final List<CurrencyReport> byCurrency;

  const MonthlyReport({required this.month, required this.byCurrency});

  bool get isEmpty => byCurrency.isEmpty;

  @override
  List<Object?> get props => [month, byCurrency];
}