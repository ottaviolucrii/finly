import 'package:finly/features/reminders/domain/entities/notification_prefs.dart';
import 'package:finly/features/reminders/domain/entities/reminder_items.dart';
import 'package:finly/features/reminders/domain/reminder_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A Tuesday morning, before the 9 o'clock reminders of the day.
  final now = DateTime(2026, 10, 6, 7);

  ReminderBill bill({
    String id = 'b1',
    String description = 'Aluguel',
    required DateTime due,
    int? leadDays,
    int cents = 150000,
  }) {
    return ReminderBill(
      id: id,
      description: description,
      amountCents: cents,
      currency: 'BRL',
      dueDate: due,
      leadDays: leadDays,
    );
  }

  ReminderInvoice invoice({
    String id = 'i1',
    String card = 'Nubank',
    required DateTime due,
    int cents = 80000,
  }) {
    return ReminderInvoice(
      id: id,
      cardName: card,
      totalCents: cents,
      currency: 'BRL',
      dueDate: due,
    );
  }

  List<ScheduledReminder> build({
    List<ReminderBill> bills = const [],
    List<ReminderInvoice> invoices = const [],
    NotificationPrefs prefs = const NotificationPrefs(),
    DateTime? at,
    int maxCount = maxScheduledReminders,
  }) {
    return buildReminders(
      bills: bills,
      invoices: invoices,
      prefs: prefs,
      now: at ?? now,
      maxCount: maxCount,
    );
  }

  group('reminderId', () {
    test('is always the same for the same reminder', () {
      expect(
        reminderId(ReminderKind.bill, 'abc', 1),
        reminderId(ReminderKind.bill, 'abc', 1),
      );
    });

    test('differs by kind, by entity and by days before', () {
      final ids = {
        reminderId(ReminderKind.bill, 'abc', 1),
        reminderId(ReminderKind.invoice, 'abc', 1),
        reminderId(ReminderKind.bill, 'abd', 1),
        reminderId(ReminderKind.bill, 'abc', 0),
      };

      expect(ids, hasLength(4));
    });

    test('is a positive 31-bit number, as notification ids must be', () {
      for (var i = 0; i < 200; i++) {
        final id = reminderId(ReminderKind.bill, 'entity-$i', i % 5);

        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThanOrEqualTo(0x7FFFFFFF));
      }
    });
  });

  group('bills', () {
    test('get one reminder the day before and one on the due day, at 9', () {
      final result = build(bills: [bill(due: DateTime(2026, 10, 9))]);

      expect(result.map((r) => r.at), [
        DateTime(2026, 10, 8, 9),
        DateTime(2026, 10, 9, 9),
      ]);
      expect(result.map((r) => r.daysBefore), [1, 0]);
    });

    test('use the lead days of the recurring item', () {
      final result = build(bills: [bill(due: DateTime(2026, 10, 12), leadDays: 3)]);

      expect(result.map((r) => r.at), [
        DateTime(2026, 10, 9, 9),
        DateTime(2026, 10, 12, 9),
      ]);
    });

    test('with 0 lead days there is only the reminder of the due day', () {
      final result = build(bills: [bill(due: DateTime(2026, 10, 12), leadDays: 0)]);

      expect(result, hasLength(1));
      expect(result.single.daysBefore, 0);
    });

    test('a huge or negative lead is kept in range', () {
      final far = build(bills: [bill(due: DateTime(2026, 11, 20), leadDays: 99)]);
      final negative = build(bills: [bill(due: DateTime(2026, 10, 12), leadDays: -4)]);

      expect(far.map((r) => r.daysBefore), [30, 0]);
      expect(negative.map((r) => r.daysBefore), [0]);
    });

    test('skip a reminder whose time has already passed', () {
      // Due today: the reminder of the day before is in the past.
      final result = build(bills: [bill(due: DateTime(2026, 10, 6))]);

      expect(result.map((r) => r.at), [DateTime(2026, 10, 6, 9)]);
    });

    test('a bill due today after the 9 o\'clock reminder has nothing to schedule', () {
      final result = build(
        bills: [bill(due: DateTime(2026, 10, 6))],
        at: DateTime(2026, 10, 6, 10),
      );

      expect(result, isEmpty);
    });

    test('an overdue bill has nothing to schedule', () {
      expect(build(bills: [bill(due: DateTime(2026, 10, 1))]), isEmpty);
    });

    test('a reminder less than a minute away is skipped, one a minute and a second away is kept', () {
      final nineSharp = DateTime(2026, 10, 6, 9);
      final due = bill(due: DateTime(2026, 10, 6), leadDays: 0);

      expect(build(bills: [due], at: nineSharp.subtract(const Duration(minutes: 1))), isEmpty);
      expect(
        build(
          bills: [due],
          at: nineSharp.subtract(const Duration(minutes: 1, seconds: 1)),
        ),
        hasLength(1),
      );
    });

    test('carry the description, the amount and the due date', () {
      final reminder = build(
        bills: [bill(description: 'Internet', cents: 9990, due: DateTime(2026, 10, 9, 14, 30))],
      ).first;

      expect(reminder.kind, ReminderKind.bill);
      expect(reminder.subject, 'Internet');
      expect(reminder.amountCents, 9990);
      expect(reminder.currency, 'BRL');
      expect(reminder.dueDate, DateTime(2026, 10, 9));
    });

    test('are left out when bill reminders are off', () {
      final result = build(
        bills: [bill(due: DateTime(2026, 10, 9))],
        prefs: const NotificationPrefs(billReminder: false),
      );

      expect(result, isEmpty);
    });

    test('count the days across the end of a month', () {
      final result = build(bills: [bill(due: DateTime(2026, 11, 1))], at: DateTime(2026, 10, 30, 7));

      expect(result.map((r) => r.at), [
        DateTime(2026, 10, 31, 9),
        DateTime(2026, 11, 1, 9),
      ]);
    });
  });

  group('invoices', () {
    test('get a reminder 3 days before and one on the due day', () {
      final result = build(invoices: [invoice(due: DateTime(2026, 10, 17))]);

      expect(result.map((r) => r.at), [
        DateTime(2026, 10, 14, 9),
        DateTime(2026, 10, 17, 9),
      ]);
      expect(result.every((r) => r.kind == ReminderKind.invoice), isTrue);
    });

    test('carry the card name and the total', () {
      final reminder = build(invoices: [invoice(card: 'XP', cents: 123456, due: DateTime(2026, 10, 17))]).first;

      expect(reminder.subject, 'XP');
      expect(reminder.amountCents, 123456);
    });

    test('skip an invoice with nothing to pay', () {
      expect(build(invoices: [invoice(due: DateTime(2026, 10, 17), cents: 0)]), isEmpty);
    });

    test('are left out when card reminders are off', () {
      final result = build(
        invoices: [invoice(due: DateTime(2026, 10, 17))],
        prefs: const NotificationPrefs(cardDue: false),
      );

      expect(result, isEmpty);
    });
  });

  group('the whole schedule', () {
    test('is empty when both kinds are off', () {
      final result = build(
        bills: [bill(due: DateTime(2026, 10, 9))],
        invoices: [invoice(due: DateTime(2026, 10, 17))],
        prefs: const NotificationPrefs(billReminder: false, cardDue: false),
      );

      expect(result, isEmpty);
    });

    test('lists the soonest first, bills and invoices together', () {
      final result = build(
        bills: [bill(id: 'b1', description: 'Aluguel', due: DateTime(2026, 10, 20))],
        invoices: [invoice(due: DateTime(2026, 10, 14))],
      );
      final times = result.map((r) => r.at).toList();

      expect([...times]..sort(), times);
      expect(result.first.kind, ReminderKind.invoice);
    });

    test('breaks a tie by kind, then by name, so the order never jumps around', () {
      final result = build(
        bills: [
          bill(id: 'b2', description: 'Zeta', due: DateTime(2026, 10, 9), leadDays: 0),
          bill(id: 'b1', description: 'Alfa', due: DateTime(2026, 10, 9), leadDays: 0),
        ],
      );

      expect(result.map((r) => r.subject), ['Alfa', 'Zeta']);
    });

    test('keeps only the nearest ones when there are too many', () {
      final bills = [
        for (var i = 0; i < 30; i++)
          bill(id: 'b$i', description: 'Conta $i', due: DateTime(2026, 10, 7 + i % 20)),
      ];

      final result = build(bills: bills, maxCount: 10);

      expect(result, hasLength(10));
      final all = build(bills: bills, maxCount: 1000);
      expect(result.map((r) => r.id), all.take(10).map((r) => r.id));
    });

    test('never repeats a notification id', () {
      final result = build(
        bills: [for (var i = 0; i < 20; i++) bill(id: 'b$i', due: DateTime(2026, 10, 9 + i))],
        invoices: [invoice(due: DateTime(2026, 10, 20))],
      );

      expect(result.map((r) => r.id).toSet(), hasLength(result.length));
    });

    test('the same input gives the same notification ids every time', () {
      final first = build(bills: [bill(due: DateTime(2026, 10, 9))]);
      final second = build(bills: [bill(due: DateTime(2026, 10, 9))]);

      expect(first.map((r) => r.id), second.map((r) => r.id));
    });

    test('a different hour moves every reminder', () {
      final result = buildReminders(
        bills: [bill(due: DateTime(2026, 10, 9))],
        invoices: const [],
        prefs: const NotificationPrefs(),
        now: now,
        hour: 18,
      );

      expect(result.map((r) => r.at.hour), [18, 18]);
    });
  });
}
