import 'package:equatable/equatable.dart';
import 'package:finly/core/money/money.dart';

/// A credit card: an account plus its settings.
class CreditCardEntity extends Equatable {
  /// The id of the card's account (cards are accounts of type credit card).
  final String accountId;
  final String workspaceId;
  final String name;
  final String currency;
  final int limitCents;

  /// Day of the month the invoice closes (1-31; short months use the last day).
  final int closingDay;

  /// Day of the month the invoice is due (1-31; short months use the last day).
  final int dueDay;

  /// Debt in cents, pending purchases included. Never negative (SRS BR-11).
  final int usedCents;

  const CreditCardEntity({
    required this.accountId,
    required this.workspaceId,
    required this.name,
    required this.currency,
    required this.limitCents,
    required this.closingDay,
    required this.dueDay,
    required this.usedCents,
  });

  /// Limit left to spend. Negative when the card is over its limit.
  int get availableCents => limitCents - usedCents;

  bool get isOverLimit => usedCents > limitCents;

  /// 0 to 1 (or more when over the limit). For a progress bar only: money is
  /// never calculated with this number.
  double get usageRatio => limitCents <= 0 ? 0 : usedCents / limitCents;

  Money get limit => Money(limitCents, currency);
  Money get used => Money(usedCents, currency);
  Money get available => Money(availableCents, currency);

  @override
  List<Object?> get props => [
        accountId,
        workspaceId,
        name,
        currency,
        limitCents,
        closingDay,
        dueDay,
        usedCents,
      ];
}