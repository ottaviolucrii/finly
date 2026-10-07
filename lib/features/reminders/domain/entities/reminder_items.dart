import 'package:equatable/equatable.dart';

enum ReminderKind { bill, invoice }

/// A pending expense that will have to be paid on [dueDate].
class ReminderBill extends Equatable {
  final String id;
  final String description;
  final int amountCents;
  final String currency;

  /// The day it is due (date only).
  final DateTime dueDate;

  /// How many days before the due date to warn, when the bill comes from a
  /// recurring item that sets it. Null means the default.
  final int? leadDays;

  const ReminderBill({
    required this.id,
    required this.description,
    required this.amountCents,
    required this.currency,
    required this.dueDate,
    this.leadDays,
  });

  @override
  List<Object?> get props =>
      [id, description, amountCents, currency, dueDate, leadDays];
}

/// A credit card invoice that is not paid yet.
class ReminderInvoice extends Equatable {
  final String id;
  final String cardName;
  final int totalCents;
  final String currency;

  /// The day it is due (date only).
  final DateTime dueDate;

  const ReminderInvoice({
    required this.id,
    required this.cardName,
    required this.totalCents,
    required this.currency,
    required this.dueDate,
  });

  @override
  List<Object?> get props => [id, cardName, totalCents, currency, dueDate];
}

/// One notification to show at [at]. It holds data, not text: the scheduler
/// turns it into words.
class ScheduledReminder extends Equatable {
  /// The notification id: the same reminder always gets the same one.
  final int id;
  final ReminderKind kind;

  /// The bill description or the card name.
  final String subject;
  final int amountCents;
  final String currency;
  final DateTime dueDate;

  /// 0 on the due day, 1 the day before...
  final int daysBefore;

  /// When the notification appears.
  final DateTime at;

  const ScheduledReminder({
    required this.id,
    required this.kind,
    required this.subject,
    required this.amountCents,
    required this.currency,
    required this.dueDate,
    required this.daysBefore,
    required this.at,
  });

  @override
  List<Object?> get props =>
      [id, kind, subject, amountCents, currency, dueDate, daysBefore, at];
}
