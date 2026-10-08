import 'package:finly/features/goals/domain/entities/goal.dart';
import 'package:finly/features/goals/domain/entities/goal_progress.dart';
import 'package:finly/features/goals/domain/goal_rules.dart';
import 'package:finly/features/goals/domain/goal_sorting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 7);

  GoalProgress progress(
    String name, {
    int balance = 0,
    int target = 500000,
    DateTime? date,
  }) {
    return GoalProgress(
      goal: Goal(
        id: name,
        workspaceId: 'w1',
        accountId: 'a1',
        currency: 'BRL',
        name: name,
        targetCents: target,
        targetDate: date,
      ),
      accountName: 'Poupança',
      balanceCents: balance,
    );
  }

  group('GoalProgress', () {
    test('works out what is saved, what is missing and the percentage', () {
      final item = progress('Reserva', balance: 125000);

      expect(item.savedCents, 125000);
      expect(item.percent, 25);
      expect(item.remainingCents, 375000);
      expect(item.achieved, isFalse);
    });

    test('an overdrawn account has saved nothing', () {
      final item = progress('Reserva', balance: -100);

      expect(item.savedCents, 0);
      expect(item.percent, 0);
      expect(item.remainingCents, 500000);
    });

    test('the target reached is achieved', () {
      final item = progress('Reserva', balance: 500000);

      expect(item.achieved, isTrue);
      expect(item.percent, 100);
      expect(item.remainingCents, 0);
      expect(item.statusAt(today), GoalStatus.achieved);
    });

    test('tells what to put aside each month to be on time', () {
      final item = progress('Reserva', balance: 125000, date: DateTime(2027, 1, 5));

      // 90 days left: three months to put aside the 3.750,00 that is missing.
      expect(item.monthlyNeededAt(today), 125000);
      expect(item.statusAt(today), GoalStatus.onTrack);
    });

    test('has nothing to put aside without a date, when reached or when overdue', () {
      expect(progress('A', balance: 1000).monthlyNeededAt(today), isNull);
      expect(progress('B', balance: 500000, date: DateTime(2027, 1, 5)).monthlyNeededAt(today), isNull);
      expect(progress('C', balance: 1000, date: DateTime(2026, 6, 30)).monthlyNeededAt(today), isNull);
    });

    test('is overdue when the date has passed', () {
      final item = progress('Reserva', balance: 1000, date: DateTime(2026, 6, 30));

      expect(item.statusAt(today), GoalStatus.overdue);
    });
  });

  group('sortGoals', () {
    List<String> names(List<GoalProgress> items) => items.map((i) => i.goal.name).toList();

    test('the goals still to reach come first, nearest date first, then the open ones, then the reached', () {
      final sorted = sortGoals([
        progress('Zeta', balance: 100),
        progress('Dezembro', balance: 100, date: DateTime(2026, 12, 1)),
        progress('Vencida', balance: 100, date: DateTime(2026, 6, 30)),
        progress('Pronta', balance: 500000),
        progress('Novembro', balance: 100, date: DateTime(2026, 11, 1)),
      ], today);

      expect(names(sorted), ['Vencida', 'Novembro', 'Dezembro', 'Zeta', 'Pronta']);
    });

    test('ties are broken by name, ignoring the case', () {
      final sorted = sortGoals([
        progress('banana', balance: 100),
        progress('Abacaxi', balance: 100),
      ], today);

      expect(names(sorted), ['Abacaxi', 'banana']);
    });

    test('the same date is ordered by name', () {
      final sorted = sortGoals([
        progress('B', balance: 100, date: DateTime(2027, 1, 1)),
        progress('A', balance: 100, date: DateTime(2027, 1, 1)),
      ], today);

      expect(names(sorted), ['A', 'B']);
    });

    test('does not change the list it is given', () {
      final items = [
        progress('B', balance: 100),
        progress('A', balance: 100),
      ];

      sortGoals(items, today);

      expect(names(items), ['B', 'A']);
    });

    test('an empty list stays empty', () {
      expect(sortGoals(const [], today), isEmpty);
    });
  });
}
