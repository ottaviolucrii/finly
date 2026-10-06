import 'package:finly/features/trash/domain/trash_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 20, 12);

  group('trashDaysLeft', () {
    test('a transaction deleted just now has all the days', () {
      expect(trashDaysLeft(now, now), trashRetentionDays);
    });

    test('counts down by whole days', () {
      expect(trashDaysLeft(now.subtract(const Duration(days: 5)), now), 25);
    });

    test('a partial last day still counts', () {
      expect(
        trashDaysLeft(now.subtract(const Duration(days: 29, hours: 12)), now),
        1,
      );
    });

    test('after the retention there is nothing left', () {
      expect(trashDaysLeft(now.subtract(const Duration(days: 30)), now), 0);
      expect(trashDaysLeft(now.subtract(const Duration(days: 45)), now), 0);
    });

    test('a deletion time in the future never goes above the retention', () {
      expect(
        trashDaysLeft(now.add(const Duration(days: 2)), now),
        trashRetentionDays,
      );
    });
  });

  group('trashDaysLeftLabel', () {
    test('says when it goes away today', () {
      expect(trashDaysLeftLabel(0), 'Será removida hoje');
    });

    test('uses the singular for one day', () {
      expect(trashDaysLeftLabel(1), 'Resta 1 dia');
    });

    test('uses the plural for several days', () {
      expect(trashDaysLeftLabel(25), 'Restam 25 dias');
    });
  });
}