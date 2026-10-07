import 'package:finly/features/reminders/domain/entities/notification_prefs.dart';
import 'package:finly/features/reminders/domain/entities/reminder_items.dart';

/// The hour of the day the reminders appear (local time).
const int reminderHour = 9;

/// Bills and invoices due in the next this-many days get their reminders
/// scheduled. The schedule is rebuilt every time the app is used.
const int reminderWindowDays = 30;

/// Android keeps only so many alarms; the nearest ones are the ones that matter.
const int maxScheduledReminders = 40;

/// A pending bill with no setting of its own is announced this many days
/// before (and on the due day).
const int defaultBillLeadDays = 1;

/// A credit card invoice is announced this many days before (and on the due
/// day).
const int invoiceLeadDays = 3;

/// The longest "days before" a recurring item can ask for.
const int maxLeadDays = 30;

/// A number for a notification that is always the same for the same reminder,
/// so scheduling it again replaces it instead of duplicating it. FNV-1a, kept
/// in 31 bits because notification ids are positive 32-bit integers.
int reminderId(ReminderKind kind, String entityId, int daysBefore) {
  var hash = 0x811C9DC5;
  for (final unit in '${kind.name}:$entityId:$daysBefore'.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}

/// Every notification to schedule, soonest first, at most [maxCount].
///
/// - A bill gets a reminder [defaultBillLeadDays] days before (or its own lead
///   days) and one on the due day. An invoice gets one [invoiceLeadDays] days
///   before and one on the due day.
/// - Each reminder appears at [hour] o'clock, and only if that moment is still
///   in the future (at least a minute from [now]).
/// - Bills only when `prefs.billReminder` is on, invoices only when
///   `prefs.cardDue` is on. An invoice with nothing to pay is skipped.
List<ScheduledReminder> buildReminders({
  required List<ReminderBill> bills,
  required List<ReminderInvoice> invoices,
  required NotificationPrefs prefs,
  required DateTime now,
  int hour = reminderHour,
  int maxCount = maxScheduledReminders,
}) {
  final earliest = now.add(const Duration(minutes: 1));
  final found = <ScheduledReminder>[];

  void add({
    required ReminderKind kind,
    required String id,
    required String subject,
    required int amountCents,
    required String currency,
    required DateTime dueDate,
    required Iterable<int> offsets,
  }) {
    for (final daysBefore in offsets) {
      final at = DateTime(dueDate.year, dueDate.month, dueDate.day - daysBefore, hour);
      if (!at.isAfter(earliest)) continue;

      found.add(
        ScheduledReminder(
          id: reminderId(kind, id, daysBefore),
          kind: kind,
          subject: subject,
          amountCents: amountCents,
          currency: currency,
          dueDate: DateTime(dueDate.year, dueDate.month, dueDate.day),
          daysBefore: daysBefore,
          at: at,
        ),
      );
    }
  }

  if (prefs.billReminder) {
    for (final bill in bills) {
      final lead = (bill.leadDays ?? defaultBillLeadDays).clamp(0, maxLeadDays);
      add(
        kind: ReminderKind.bill,
        id: bill.id,
        subject: bill.description,
        amountCents: bill.amountCents,
        currency: bill.currency,
        dueDate: bill.dueDate,
        offsets: {lead, 0},
      );
    }
  }

  if (prefs.cardDue) {
    for (final invoice in invoices) {
      if (invoice.totalCents <= 0) continue;
      add(
        kind: ReminderKind.invoice,
        id: invoice.id,
        subject: invoice.cardName,
        amountCents: invoice.totalCents,
        currency: invoice.currency,
        dueDate: invoice.dueDate,
        offsets: const [invoiceLeadDays, 0],
      );
    }
  }

  found.sort((a, b) {
    final byTime = a.at.compareTo(b.at);
    if (byTime != 0) return byTime;
    final byKind = a.kind.index.compareTo(b.kind.index);
    if (byKind != 0) return byKind;
    final bySubject = a.subject.compareTo(b.subject);
    return bySubject != 0 ? bySubject : a.id.compareTo(b.id);
  });

  // The same id twice would make the second replace the first.
  final seen = <int>{};
  final unique = [
    for (final reminder in found)
      if (seen.add(reminder.id)) reminder,
  ];

  return unique.take(maxCount).toList();
}
