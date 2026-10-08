import 'package:equatable/equatable.dart';
import 'package:finly/features/tax_reserve/domain/tax_reserve_rules.dart';

/// What the tax reserve of one company workspace is made from, for one month.
class TaxReserveData extends Equatable {
  /// The share of the income to set aside, in basis points (650 = 6.5%).
  /// Zero means the person has not chosen one yet.
  final int percentBps;

  /// The base currency of the workspace: the only one the reserve is about.
  final String currency;

  /// What came in during the month (only what already happened).
  final int incomeCents;

  /// Spent on tax categories in the month (paid and pending).
  final int taxCents;

  const TaxReserveData({
    required this.percentBps,
    required this.currency,
    required this.incomeCents,
    required this.taxCents,
  });

  bool get hasPercent => percentBps > 0;

  /// What should be set aside from this month's income.
  int get reserveCents => reserveFor(incomeCents, percentBps);

  /// What is left of the reserve after the taxes of the month (never below 0).
  int get remainingCents => reserveCents > taxCents ? reserveCents - taxCents : 0;

  /// How much the taxes of the month went over the reserve (0 when they did not).
  int get exceededCents => taxCents > reserveCents ? taxCents - reserveCents : 0;

  TaxReserveData withPercent(int bps) {
    return TaxReserveData(
      percentBps: bps,
      currency: currency,
      incomeCents: incomeCents,
      taxCents: taxCents,
    );
  }

  @override
  List<Object?> get props => [percentBps, currency, incomeCents, taxCents];
}
