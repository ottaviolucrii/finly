import 'package:finly/features/budgets/domain/budget_rules.dart';
import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BudgetEntity version(String category, DateTime from, int limit) {
    return BudgetEntity(
      id: '$category-${from.month}',
      workspaceId: 'w1',
      categoryId: category,
      effectiveFrom: from,
      limitCents: limit,
      currency: 'BRL',
    );
  }

  group('monthStart and addMonths', () {
    test('monthStart drops the day and the time', () {
      expect(monthStart(DateTime(2026, 3, 17, 14, 30)), DateTime(2026, 3));
    });

    test('addMonths moves forward and back', () {
      expect(addMonths(DateTime(2026, 3), 1), DateTime(2026, 4));
      expect(addMonths(DateTime(2026, 3), -2), DateTime(2026, 1));
    });

    test('addMonths rolls the year over', () {
      expect(addMonths(DateTime(2026, 12), 1), DateTime(2027, 1));
      expect(addMonths(DateTime(2026, 1), -1), DateTime(2025, 12));
    });
  });

  group('isoDate', () {
    test('uses the year-month-day format of the database', () {
      expect(isoDate(DateTime(2026, 3, 5)), '2026-03-05');
      expect(isoDate(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('activeBudget', () {
    final march = version('food', DateTime(2026, 3), 80000);
    final june = version('food', DateTime(2026, 6), 100000);
    final transport = version('transport', DateTime(2026, 3), 30000);
    final all = [june, transport, march];

    test('is the latest version that started on or before the month', () {
      expect(activeBudget(all, 'food', DateTime(2026, 3, 20)), march);
      expect(activeBudget(all, 'food', DateTime(2026, 5)), march);
      expect(activeBudget(all, 'food', DateTime(2026, 6)), june);
      expect(activeBudget(all, 'food', DateTime(2027, 1)), june);
    });

    test('is null before the first version', () {
      expect(activeBudget(all, 'food', DateTime(2026, 2, 28)), isNull);
    });

    test('only looks at the requested category', () {
      expect(activeBudget(all, 'transport', DateTime(2026, 8)), transport);
      expect(activeBudget(all, 'health', DateTime(2026, 8)), isNull);
    });

    test('is null when there are no versions', () {
      expect(activeBudget(const [], 'food', DateTime(2026, 3)), isNull);
    });
  });

  group('end markers (limit 0)', () {
    final start = version('food', DateTime(2026, 3), 80000);
    final stop = version('food', DateTime(2026, 6), 0);
    final restart = version('food', DateTime(2026, 9), 50000);

    test('stop the budget from their month on, and keep earlier months', () {
      final all = [start, stop];

      expect(activeBudget(all, 'food', DateTime(2026, 5)), start);
      expect(activeBudget(all, 'food', DateTime(2026, 6)), isNull);
      expect(activeBudget(all, 'food', DateTime(2026, 12)), isNull);
    });

    test('a later version starts the budget again', () {
      final all = [start, stop, restart];

      expect(activeBudget(all, 'food', DateTime(2026, 7)), isNull);
      expect(activeBudget(all, 'food', DateTime(2026, 10)), restart);
    });
  });
}