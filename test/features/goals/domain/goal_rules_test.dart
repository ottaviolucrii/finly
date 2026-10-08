import 'package:finly/features/goals/domain/goal_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 7);

  group('savedFor', () {
    test('is the balance of the account', () {
      expect(savedFor(5000), 5000);
    });

    test('an empty or overdrawn account has saved nothing', () {
      expect(savedFor(0), 0);
      expect(savedFor(-300), 0);
    });
  });

  group('progressPercent', () {
    test('half of the target is 50%', () {
      expect(progressPercent(500, 1000), 50);
    });

    test('rounds down, so it never shows 100% before the target', () {
      expect(progressPercent(999, 1000), 99);
      expect(progressPercent(1, 1000), 0);
    });

    test('the target reached, or more, is 100%', () {
      expect(progressPercent(1000, 1000), 100);
      expect(progressPercent(1500, 1000), 100);
    });

    test('nothing saved is 0%', () {
      expect(progressPercent(0, 1000), 0);
      expect(progressPercent(-5, 1000), 0);
    });

    test('a target that is not above zero gives 0%', () {
      expect(progressPercent(100, 0), 0);
    });

    test('big numbers do not overflow', () {
      expect(progressPercent(5000000000000, 10000000000000), 50);
    });
  });

  group('remainingFor', () {
    test('is what is missing', () {
      expect(remainingFor(400, 1000), 600);
    });

    test('is zero once the target is reached', () {
      expect(remainingFor(1000, 1000), 0);
      expect(remainingFor(2000, 1000), 0);
    });
  });

  group('daysLeft', () {
    test('counts the days to the date', () {
      expect(daysLeft(today, DateTime(2026, 10, 17)), 10);
    });

    test('today is zero days', () {
      expect(daysLeft(today, DateTime(2026, 10, 7)), 0);
    });

    test('a date that has passed is negative', () {
      expect(daysLeft(today, DateTime(2026, 10, 6)), -1);
    });

    test('counts across the end of a month and a year', () {
      expect(daysLeft(DateTime(2026, 10, 30), DateTime(2026, 11, 2)), 3);
      expect(daysLeft(DateTime(2026, 12, 30), DateTime(2027, 1, 2)), 3);
    });

    test('counts February 29', () {
      expect(daysLeft(DateTime(2028, 2, 28), DateTime(2028, 3, 1)), 2);
    });

    test('ignores the time of day', () {
      expect(daysLeft(DateTime(2026, 10, 7, 23, 59), DateTime(2026, 10, 8, 0, 1)), 1);
    });
  });

  group('monthsLeft', () {
    test('none left is zero months', () {
      expect(monthsLeft(0), 0);
      expect(monthsLeft(-5), 0);
    });

    test('every started 30 days is a month, and at least one', () {
      expect(monthsLeft(1), 1);
      expect(monthsLeft(30), 1);
      expect(monthsLeft(31), 2);
      expect(monthsLeft(60), 2);
      expect(monthsLeft(61), 3);
      expect(monthsLeft(365), 13);
    });
  });

  group('monthlyNeededFor', () {
    test('splits what is missing over the months left', () {
      expect(monthlyNeededFor(600000, 90), 200000);
    });

    test('rounds up to the cent, so the goal is not missed by a cent', () {
      expect(monthlyNeededFor(100001, 90), 33334);
      expect(monthlyNeededFor(1, 90), 1);
    });

    test('one month left asks for all of it', () {
      expect(monthlyNeededFor(1000, 20), 1000);
    });

    test('is null when nothing is missing', () {
      expect(monthlyNeededFor(0, 90), isNull);
    });

    test('is null when the date is today or has passed', () {
      expect(monthlyNeededFor(1000, 0), isNull);
      expect(monthlyNeededFor(1000, -3), isNull);
    });
  });

  group('goalStatusFor', () {
    GoalStatus status(int saved, {DateTime? date, int target = 1000}) {
      return goalStatusFor(savedCents: saved, targetCents: target, targetDate: date, today: today);
    }

    test('the target reached is achieved', () {
      expect(status(1000), GoalStatus.achieved);
      expect(status(2000), GoalStatus.achieved);
    });

    test('achieved wins over a date that has passed', () {
      expect(status(1000, date: DateTime(2025, 1, 1)), GoalStatus.achieved);
    });

    test('without a date it is open', () {
      expect(status(500), GoalStatus.open);
    });

    test('with a date to come it is on track', () {
      expect(status(500, date: DateTime(2027, 1, 1)), GoalStatus.onTrack);
    });

    test('a date that is today is not overdue yet', () {
      expect(status(500, date: DateTime(2026, 10, 7)), GoalStatus.onTrack);
    });

    test('a date that has passed is overdue', () {
      expect(status(500, date: DateTime(2026, 10, 6)), GoalStatus.overdue);
    });
  });
}
