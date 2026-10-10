import 'package:equatable/equatable.dart';
import 'package:finly/core/money/money.dart';

/// What can be wrong with the amount typed to pay an invoice.
enum PaymentAmountProblem {
  /// Nothing typed yet: no message, the button just waits.
  empty,

  /// Not an amount ("abc", "1,2,3").
  invalid,

  /// Zero or less.
  notPositive,

  /// More than what is still owed.
  aboveOwed,
}

/// The result of checking an amount typed to pay an invoice.
class PaymentAmountCheck extends Equatable {
  /// The amount in cents, when it can be paid.
  final int? cents;

  final PaymentAmountProblem? problem;

  /// The amount is everything that is still owed (it settles the invoice).
  final bool isFull;

  const PaymentAmountCheck.valid(int this.cents, {required this.isFull}) : problem = null;

  const PaymentAmountCheck.problem(PaymentAmountProblem this.problem)
      : cents = null,
        isFull = false;

  bool get isValid => cents != null;

  @override
  List<Object?> get props => [cents, problem, isFull];
}

/// Checks [text] (Brazilian format: "1.234,56", "250", "12,5") as a payment of
/// part of an invoice, or all of it, when [remainingCents] is still owed.
PaymentAmountCheck checkPaymentAmount(
  String text, {
  required String currency,
  required int remainingCents,
}) {
  if (text.trim().isEmpty) {
    return const PaymentAmountCheck.problem(PaymentAmountProblem.empty);
  }

  final money = Money.tryParse(text, currency);
  if (money == null) {
    return const PaymentAmountCheck.problem(PaymentAmountProblem.invalid);
  }
  if (money.cents <= 0) {
    return const PaymentAmountCheck.problem(PaymentAmountProblem.notPositive);
  }
  if (money.cents > remainingCents) {
    return const PaymentAmountCheck.problem(PaymentAmountProblem.aboveOwed);
  }

  return PaymentAmountCheck.valid(money.cents, isFull: money.cents == remainingCents);
}
