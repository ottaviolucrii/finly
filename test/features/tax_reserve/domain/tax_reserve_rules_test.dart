import 'package:finly/features/tax_reserve/domain/entities/tax_reserve_data.dart';
import 'package:finly/features/tax_reserve/domain/tax_reserve_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reserveFor', () {
    test('takes the percentage of the income', () {
      expect(reserveFor(500000, 650), 32500); // 6.5% of 5.000,00
      expect(reserveFor(1000000, 600), 60000); // 6%
    });

    test('100% reserves all of it', () {
      expect(reserveFor(123456, 10000), 123456);
    });

    test('rounds to the nearest cent, halves up', () {
      expect(reserveFor(1001, 650), 65); // 65.065
      expect(reserveFor(1, 5000), 1); // 0.5
      expect(reserveFor(3, 1666), 0); // 0.4998
      expect(reserveFor(1, 4999), 0); // 0.4999
    });

    test('nothing comes in, nothing is reserved', () {
      expect(reserveFor(0, 650), 0);
      expect(reserveFor(-500, 650), 0);
    });

    test('no percentage, no reserve', () {
      expect(reserveFor(500000, 0), 0);
      expect(reserveFor(500000, -10), 0);
    });

    test('a very large income does not overflow', () {
      expect(reserveFor(100000000000000, 10000), 100000000000000);
    });
  });

  group('percentText', () {
    test('a whole percentage has no decimals', () {
      expect(percentText(600), '6%');
      expect(percentText(10000), '100%');
      expect(percentText(0), '0%');
    });

    test('uses a decimal comma and drops the trailing zero', () {
      expect(percentText(650), '6,5%');
      expect(percentText(50), '0,5%');
    });

    test('keeps two decimals when they are needed', () {
      expect(percentText(625), '6,25%');
      expect(percentText(605), '6,05%');
      expect(percentText(1), '0,01%');
    });
  });

  group('percentInput', () {
    test('is the percentage without the sign', () {
      expect(percentInput(650), '6,5');
      expect(percentInput(600), '6');
      expect(percentInput(625), '6,25');
    });
  });

  group('parsePercentToBps', () {
    test('reads a whole number', () {
      expect(parsePercentToBps('6'), 600);
      expect(parsePercentToBps('0'), 0);
      expect(parsePercentToBps('100'), 10000);
    });

    test('reads a decimal comma or a decimal point', () {
      expect(parsePercentToBps('6,5'), 650);
      expect(parsePercentToBps('6.5'), 650);
    });

    test('reads one or two decimals correctly', () {
      expect(parsePercentToBps('6,05'), 605);
      expect(parsePercentToBps('6,25'), 625);
      expect(parsePercentToBps('6,5'), isNot(605));
    });

    test('ignores spaces and a percent sign', () {
      expect(parsePercentToBps(' 7 % '), 700);
      expect(parsePercentToBps('7,5%'), 750);
    });

    test('refuses an empty text and letters', () {
      expect(parsePercentToBps(''), isNull);
      expect(parsePercentToBps('   '), isNull);
      expect(parsePercentToBps('seis'), isNull);
      expect(parsePercentToBps('6a'), isNull);
    });

    test('refuses more than two decimals', () {
      expect(parsePercentToBps('6,125'), isNull);
    });

    test('refuses a negative value', () {
      expect(parsePercentToBps('-5'), isNull);
    });

    test('refuses more than 100', () {
      expect(parsePercentToBps('100,01'), isNull);
      expect(parsePercentToBps('101'), isNull);
      expect(parsePercentToBps('1000'), isNull);
    });

    test('refuses two separators', () {
      expect(parsePercentToBps('1,2,3'), isNull);
      expect(parsePercentToBps('1.2.3'), isNull);
    });

    test('is the opposite of percentInput', () {
      for (final bps in [0, 1, 50, 600, 605, 625, 650, 1234, 10000]) {
        expect(parsePercentToBps(percentInput(bps)), bps, reason: '$bps');
      }
    });
  });

  group('TaxReserveData', () {
    const data = TaxReserveData(
      percentBps: 650,
      currency: 'BRL',
      incomeCents: 500000,
      taxCents: 12000,
    );

    test('works out the reserve from the income', () {
      expect(data.reserveCents, 32500);
    });

    test('what is left of the reserve after the taxes', () {
      expect(data.remainingCents, 20500);
      expect(data.exceededCents, 0);
    });

    test('taxes above the reserve are shown as exceeded, not as a negative reserve', () {
      const over = TaxReserveData(
        percentBps: 650,
        currency: 'BRL',
        incomeCents: 500000,
        taxCents: 40000,
      );

      expect(over.remainingCents, 0);
      expect(over.exceededCents, 7500);
    });

    test('taxes exactly equal to the reserve leave nothing and exceed nothing', () {
      const exact = TaxReserveData(
        percentBps: 650,
        currency: 'BRL',
        incomeCents: 500000,
        taxCents: 32500,
      );

      expect(exact.remainingCents, 0);
      expect(exact.exceededCents, 0);
    });

    test('without a percentage there is no reserve', () {
      const none = TaxReserveData(
        percentBps: 0,
        currency: 'BRL',
        incomeCents: 500000,
        taxCents: 0,
      );

      expect(none.hasPercent, isFalse);
      expect(none.reserveCents, 0);
      expect(data.hasPercent, isTrue);
    });

    test('withPercent changes only the percentage', () {
      final changed = data.withPercent(1000);

      expect(changed.percentBps, 1000);
      expect(changed.incomeCents, data.incomeCents);
      expect(changed.taxCents, data.taxCents);
      expect(changed.currency, 'BRL');
      expect(changed.reserveCents, 50000);
    });
  });
}
