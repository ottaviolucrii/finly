import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:finly/features/recurring/domain/recurrence_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('recurrenceDate', () {
    test('daily counts days from the start', () {
      final start = DateTime(2026, 3, 1);

      expect(recurrenceDate(start, RecurrenceFrequency.daily, 3, 0), start);
      expect(
        recurrenceDate(start, RecurrenceFrequency.daily, 3, 2),
        DateTime(2026, 3, 7),
      );
    });

    test('weekly counts weeks from the start', () {
      final start = DateTime(2026, 3, 2);

      expect(
        recurrenceDate(start, RecurrenceFrequency.weekly, 2, 1),
        DateTime(2026, 3, 16),
      );
      expect(
        recurrenceDate(start, RecurrenceFrequency.weekly, 1, 5),
        DateTime(2026, 4, 6),
      );
    });

    test('monthly keeps the day', () {
      final start = DateTime(2026, 1, 15);

      expect(
        recurrenceDate(start, RecurrenceFrequency.monthly, 1, 1),
        DateTime(2026, 2, 15),
      );
      expect(
        recurrenceDate(start, RecurrenceFrequency.monthly, 2, 3),
        DateTime(2026, 7, 15),
      );
    });

    test('monthly from the 31st uses the last day of shorter months', () {
      final start = DateTime(2026, 1, 31);

      expect(
        recurrenceDate(start, RecurrenceFrequency.monthly, 1, 1),
        DateTime(2026, 2, 28),
      );
      // Counted from the start, so it goes back to the 31st.
      expect(
        recurrenceDate(start, RecurrenceFrequency.monthly, 1, 2),
        DateTime(2026, 3, 31),
      );
      expect(
        recurrenceDate(start, RecurrenceFrequency.monthly, 1, 3),
        DateTime(2026, 4, 30),
      );
      expect(
        recurrenceDate(start, RecurrenceFrequency.monthly, 1, 13),
        DateTime(2027, 2, 28),
      );
    });

    test('monthly rolls the year over', () {
      expect(
        recurrenceDate(
          DateTime(2026, 11, 10),
          RecurrenceFrequency.monthly,
          1,
          3,
        ),
        DateTime(2027, 2, 10),
      );
    });

    test('yearly handles February 29', () {
      final start = DateTime(2024, 2, 29);

      expect(
        recurrenceDate(start, RecurrenceFrequency.yearly, 1, 1),
        DateTime(2025, 2, 28),
      );
      expect(
        recurrenceDate(start, RecurrenceFrequency.yearly, 1, 4),
        DateTime(2028, 2, 29),
      );
    });
  });

  group('nextOccurrence', () {
    final start = DateTime(2026, 3, 10);

    DateTime? next(
      DateTime today, {
      DateTime? end,
      RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
      int interval = 1,
    }) {
      return nextOccurrence(
        start: start,
        frequency: frequency,
        intervalCount: interval,
        endDate: end,
        today: today,
      );
    }

    test('before the start it is the start date', () {
      expect(next(DateTime(2026, 1, 1)), start);
    });

    test('on an occurrence day it is that day', () {
      expect(next(DateTime(2026, 3, 10, 18, 30)), DateTime(2026, 3, 10));
    });

    test('after an occurrence it is the next one', () {
      expect(next(DateTime(2026, 3, 11)), DateTime(2026, 4, 10));
      expect(next(DateTime(2026, 12, 20)), DateTime(2027, 1, 10));
    });

    test('works with an interval', () {
      expect(
        next(DateTime(2026, 3, 11), interval: 2),
        DateTime(2026, 5, 10),
      );
    });

    test('works for daily items that started long ago', () {
      expect(
        next(
          DateTime(2030, 6, 15),
          frequency: RecurrenceFrequency.daily,
        ),
        DateTime(2030, 6, 15),
      );
    });

    test('the end date itself is still an occurrence', () {
      expect(
        next(DateTime(2026, 5, 10), end: DateTime(2026, 5, 10)),
        DateTime(2026, 5, 10),
      );
    });

    test('is null once the series has ended', () {
      expect(next(DateTime(2026, 5, 11), end: DateTime(2026, 5, 10)), isNull);
      expect(next(DateTime(2026, 6, 1), end: DateTime(2026, 5, 10)), isNull);
    });
  });
}