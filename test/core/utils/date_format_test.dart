import 'package:finly/core/utils/date_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatDateBr', () {
    test('uses day/month/year with two digits', () {
      expect(formatDateBr(DateTime(2026, 10, 2)), '02/10/2026');
      expect(formatDateBr(DateTime(2026, 12, 25)), '25/12/2026');
    });
  });

  group('dayLabel', () {
    final now = DateTime(2026, 10, 2, 0, 1);

    test('is "Hoje" for any time on the same calendar day', () {
      expect(dayLabel(DateTime(2026, 10, 2, 23, 59), now), 'Hoje');
      expect(dayLabel(DateTime(2026, 10, 2, 0, 0), now), 'Hoje');
    });

    test('is "Ontem" for the previous calendar day, even minutes ago', () {
      expect(dayLabel(DateTime(2026, 10, 1, 23, 59), now), 'Ontem');
    });

    test('is the date for older days', () {
      expect(dayLabel(DateTime(2026, 9, 30, 12), now), '30/09/2026');
    });

    test('is the date for future days', () {
      expect(dayLabel(DateTime(2026, 10, 3, 12), now), '03/10/2026');
    });
  });
}