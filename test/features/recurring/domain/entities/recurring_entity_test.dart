import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:finly/features/recurring/domain/entities/recurring_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RecurringEntity entity({DateTime? endDate}) {
    return RecurringEntity(
      id: 'r1',
      workspaceId: 'w1',
      accountId: 'a1',
      categoryId: null,
      type: TransactionType.expense,
      amountCents: 120000,
      currency: 'BRL',
      description: 'Aluguel',
      frequency: RecurrenceFrequency.monthly,
      intervalCount: 1,
      startDate: DateTime(2026, 3, 5),
      endDate: endDate,
      isActive: true,
    );
  }

  group('RecurrenceFrequency', () {
    test('database labels match the enum and survive a round trip', () {
      expect(RecurrenceFrequency.daily.dbValue, 'daily');
      expect(RecurrenceFrequency.weekly.dbValue, 'weekly');
      expect(RecurrenceFrequency.monthly.dbValue, 'monthly');
      expect(RecurrenceFrequency.yearly.dbValue, 'yearly');
      for (final frequency in RecurrenceFrequency.values) {
        expect(RecurrenceFrequency.fromDb(frequency.dbValue), frequency);
      }
    });

    test('an unknown label fails loudly', () {
      expect(() => RecurrenceFrequency.fromDb('hourly'), throwsArgumentError);
    });
  });

  group('RecurringEntity', () {
    test('exposes the amount as Money', () {
      expect(entity().amount.format(), r'R$ 1.200,00');
    });

    test('knows its next date', () {
      expect(entity().nextDate(DateTime(2026, 3, 6)), DateTime(2026, 4, 5));
    });

    test('has no next date once it has ended', () {
      expect(
        entity(endDate: DateTime(2026, 4, 5)).nextDate(DateTime(2026, 4, 6)),
        isNull,
      );
    });
  });
}