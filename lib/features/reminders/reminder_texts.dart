import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/reminders/domain/entities/reminder_items.dart';

String _when(int daysBefore) {
  if (daysBefore <= 0) return 'hoje';
  if (daysBefore == 1) return 'amanhã';
  return 'em $daysBefore dias';
}

/// The headline of a notification (Portuguese for now; replaced by proper
/// localisation in a later phase).
String reminderTitle(ScheduledReminder reminder) {
  switch (reminder.kind) {
    case ReminderKind.bill:
      return 'Vence ${_when(reminder.daysBefore)}: ${reminder.subject}';
    case ReminderKind.invoice:
      return 'Fatura ${reminder.subject} vence ${_when(reminder.daysBefore)}';
  }
}

/// The second line of a notification: the amount and the due date.
String reminderBody(ScheduledReminder reminder) {
  final amount = Money(reminder.amountCents, reminder.currency).format();
  final date = formatDateBr(reminder.dueDate);

  switch (reminder.kind) {
    case ReminderKind.bill:
      return '$amount · $date';
    case ReminderKind.invoice:
      return 'Total $amount · vencimento $date';
  }
}
