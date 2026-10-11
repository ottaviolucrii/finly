import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:finly/features/recurring/domain/entities/recurring_entity.dart';
import 'package:finly/features/recurring/presentation/pages/recurring_page.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RecurringEntity item(
    RecurrenceFrequency frequency, {
    int amount = 120000,
    int every = 1,
    bool active = true,
    DateTime? end,
  }) {
    return RecurringEntity(
      id: 'r1',
      workspaceId: 'w1',
      accountId: 'a1',
      categoryId: null,
      type: TransactionType.expense,
      amountCents: amount,
      currency: 'BRL',
      description: 'Aluguel',
      frequency: frequency,
      intervalCount: every,
      startDate: DateTime(2026, 1, 15),
      endDate: end,
      isActive: active,
    );
  }

  group('monthlyEquivalentCents', () {
    test('monthly is the amount itself', () {
      expect(monthlyEquivalentCents(item(RecurrenceFrequency.monthly)), 120000);
    });

    test('every two months is half', () {
      expect(monthlyEquivalentCents(item(RecurrenceFrequency.monthly, every: 2)), 60000);
    });

    test('yearly is a twelfth', () {
      expect(monthlyEquivalentCents(item(RecurrenceFrequency.yearly)), 10000);
    });

    test('weekly counts 52 weeks over 12 months', () {
      expect(monthlyEquivalentCents(item(RecurrenceFrequency.weekly, amount: 1200)), 5200);
    });

    test('daily counts 365 days over 12 months', () {
      expect(monthlyEquivalentCents(item(RecurrenceFrequency.daily, amount: 1200)), 36500);
    });
  });

  group('isRunning', () {
    final today = DateTime(2026, 10, 11);

    test('an active item with a next date runs', () {
      expect(isRunning(item(RecurrenceFrequency.monthly), today), isTrue);
    });

    test('a paused item does not', () {
      expect(isRunning(item(RecurrenceFrequency.monthly, active: false), today), isFalse);
    });

    test('an item that already ended does not', () {
      expect(isRunning(item(RecurrenceFrequency.monthly, end: DateTime(2026, 5, 1)), today), isFalse);
    });
  });
}
