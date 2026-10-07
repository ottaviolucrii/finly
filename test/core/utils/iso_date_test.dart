import 'package:finly/core/utils/iso_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isoDate', () {
    test('writes year-month-day', () {
      expect(isoDate(DateTime(2026, 10, 17)), '2026-10-17');
    });

    test('pads the month and the day to two digits', () {
      expect(isoDate(DateTime(2026, 3, 5)), '2026-03-05');
      expect(isoDate(DateTime(2026, 1, 9)), '2026-01-09');
    });

    test('ignores the time of day', () {
      expect(isoDate(DateTime(2026, 3, 5, 23, 59, 59)), '2026-03-05');
      expect(isoDate(DateTime(2026, 3, 5, 0, 0, 1)), '2026-03-05');
    });

    test('pads a short year to four digits', () {
      expect(isoDate(DateTime(5, 3, 7)), '0005-03-07');
    });

    test('the last day of a leap year', () {
      expect(isoDate(DateTime(2028, 2, 29)), '2028-02-29');
    });
  });

  group('parseIsoDate', () {
    test('reads year-month-day as that day', () {
      expect(parseIsoDate('2026-10-17'), DateTime(2026, 10, 17));
      expect(parseIsoDate('2026-01-05'), DateTime(2026, 1, 5));
    });

    test('reads the date at the start of a timestamp', () {
      expect(parseIsoDate('2026-10-17T15:30:00+00:00'), DateTime(2026, 10, 17));
    });

    test('is the opposite of isoDate', () {
      final day = DateTime(2028, 2, 29);

      expect(parseIsoDate(isoDate(day)), day);
    });

    test('refuses text that is not a date', () {
      expect(() => parseIsoDate('17/10/2026'), throwsFormatException);
      expect(() => parseIsoDate(''), throwsFormatException);
      expect(() => parseIsoDate('amanhã'), throwsFormatException);
    });
  });
}
