import 'package:equatable/equatable.dart';

/// Income and expenses that already happened in one month and currency.
class MonthlyFlowEntry extends Equatable {
  /// First day of the month.
  final DateTime month;
  final String currency;
  final int incomeCents;
  final int expenseCents;

  const MonthlyFlowEntry({
    required this.month,
    required this.currency,
    required this.incomeCents,
    required this.expenseCents,
  });

  @override
  List<Object?> get props => [month, currency, incomeCents, expenseCents];
}