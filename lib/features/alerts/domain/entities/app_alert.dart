import 'package:equatable/equatable.dart';

/// What an alert is about. The order is the urgency: the lower, the earlier it
/// is listed.
enum AlertKind {
  billOverdue,
  budgetOver,
  billDueToday,
  budgetNear,
  billDueSoon,
}

/// Something that needs the user's attention. It holds data, not text: the
/// screen turns it into words.
class AppAlert extends Equatable {
  final AlertKind kind;

  /// The category name (budget alerts) or the description (bill alerts).
  final String subject;
  final String currency;

  /// What was spent (budget alerts) or the amount (bill alerts).
  final int amountCents;

  /// The budget limit. Null for bills.
  final int? limitCents;

  /// Whole percent of the budget already used. Null for bills.
  final int? percent;

  /// The due date. Null for budgets.
  final DateTime? dueDate;

  /// Days from today to the due date: negative when overdue. Null for budgets.
  final int? daysUntilDue;

  const AppAlert({
    required this.kind,
    required this.subject,
    required this.currency,
    required this.amountCents,
    this.limitCents,
    this.percent,
    this.dueDate,
    this.daysUntilDue,
  });

  bool get isBudget => kind == AlertKind.budgetOver || kind == AlertKind.budgetNear;

  /// Needs action now: something overdue, over its limit or due today.
  bool get isUrgent =>
      kind == AlertKind.billOverdue ||
      kind == AlertKind.budgetOver ||
      kind == AlertKind.billDueToday;

  @override
  List<Object?> get props => [
        kind,
        subject,
        currency,
        amountCents,
        limitCents,
        percent,
        dueDate,
        daysUntilDue,
      ];
}