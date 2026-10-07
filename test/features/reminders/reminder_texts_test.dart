import 'package:finly/features/reminders/domain/entities/reminder_items.dart';
import 'package:finly/features/reminders/reminder_texts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ScheduledReminder reminder(
    ReminderKind kind, {
    String subject = 'Aluguel',
    int cents = 150000,
    int daysBefore = 0,
  }) {
    return ScheduledReminder(
      id: 1,
      kind: kind,
      subject: subject,
      amountCents: cents,
      currency: 'BRL',
      dueDate: DateTime(2026, 10, 9),
      daysBefore: daysBefore,
      at: DateTime(2026, 10, 9, 9),
    );
  }

  group('reminderTitle', () {
    test('a bill due today', () {
      expect(reminderTitle(reminder(ReminderKind.bill)), 'Vence hoje: Aluguel');
    });

    test('a bill due tomorrow', () {
      expect(
        reminderTitle(reminder(ReminderKind.bill, daysBefore: 1)),
        'Vence amanhã: Aluguel',
      );
    });

    test('a bill due in several days says how many', () {
      expect(
        reminderTitle(reminder(ReminderKind.bill, daysBefore: 3)),
        'Vence em 3 dias: Aluguel',
      );
    });

    test('an invoice names the card', () {
      expect(
        reminderTitle(reminder(ReminderKind.invoice, subject: 'Nubank')),
        'Fatura Nubank vence hoje',
      );
      expect(
        reminderTitle(reminder(ReminderKind.invoice, subject: 'Nubank', daysBefore: 1)),
        'Fatura Nubank vence amanhã',
      );
      expect(
        reminderTitle(reminder(ReminderKind.invoice, subject: 'Nubank', daysBefore: 3)),
        'Fatura Nubank vence em 3 dias',
      );
    });
  });

  group('reminderBody', () {
    test('a bill shows the amount and the date', () {
      final text = reminderBody(reminder(ReminderKind.bill, cents: 150000));

      expect(text, 'R\$ 1.500,00 · 09/10/2026');
    });

    test('an invoice shows the total and the due date', () {
      final text = reminderBody(reminder(ReminderKind.invoice, cents: 80050));

      expect(text, 'Total R\$ 800,50 · vencimento 09/10/2026');
    });

    test('uses the symbol of the currency', () {
      final text = reminderBody(
        ScheduledReminder(
          id: 1,
          kind: ReminderKind.bill,
          subject: 'Hosting',
          amountCents: 2500,
          currency: 'USD',
          dueDate: DateTime(2026, 10, 9),
          daysBefore: 0,
          at: DateTime(2026, 10, 9, 9),
        ),
      );

      expect(text, startsWith('US\$ 25,00'));
    });
  });
}
