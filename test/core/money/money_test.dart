import 'package:finly/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('format', () {
    test('uses the symbol, a dot for thousands and a comma for decimals', () {
      expect(const Money(123456, 'BRL').format(), r'R$ 1.234,56');
      expect(const Money(100000000, 'BRL').format(), r'R$ 1.000.000,00');
    });

    test('keeps two decimals for small amounts and zero', () {
      expect(const Money(0, 'BRL').format(), r'R$ 0,00');
      expect(const Money(5, 'BRL').format(), r'R$ 0,05');
    });

    test('puts the minus sign before the symbol', () {
      expect(const Money(-123456, 'BRL').format(), r'-R$ 1.234,56');
      expect(const Money(-5, 'BRL').format(), r'-R$ 0,05');
    });

    test('knows USD and EUR and falls back to the currency code', () {
      expect(const Money(99, 'USD').format(), r'US$ 0,99');
      expect(const Money(250000, 'EUR').format(), '€ 2.500,00');
      expect(const Money(1000, 'GBP').format(), 'GBP 10,00');
    });

    test('can leave the symbol out', () {
      expect(const Money(123456, 'BRL').format(withSymbol: false), '1.234,56');
      expect(const Money(-5, 'BRL').format(withSymbol: false), '-0,05');
    });
  });

  group('tryParse accepts', () {
    const valid = {
      '1.234,56': 123456,
      '1234,56': 123456,
      '1234,5': 123450,
      '1.234,5': 123450,
      '12.50': 1250,
      '12.5': 1250,
      '1.23': 123,
      '1.234': 123400,
      '1.234.567': 123456700,
      '100.000,00': 10000000,
      '10': 1000,
      '0': 0,
      '0,05': 5,
      r'R$ 10': 1000,
      r'R$ 1.234,56': 123456,
      '-50,25': -5025,
      r'-R$ 5': -500,
      r'R$-5': -500,
      '12 000,00': 1200000,
    };

    valid.forEach((input, cents) {
      test('"$input" as $cents cents', () {
        expect(Money.tryParse(input, 'BRL'), Money(cents, 'BRL'));
      });
    });
  });

  group('tryParse rejects', () {
    const invalid = [
      'abc',
      '',
      '   ',
      '12,345',
      '1,2,3',
      '1.2.3',
      '10.',
      '.50',
      ',50',
      '999999999999999',
    ];

    for (final input in invalid) {
      test('"$input"', () {
        expect(Money.tryParse(input, 'BRL'), isNull);
      });
    }
  });

  group('arithmetic', () {
    test('adds and subtracts amounts of the same currency', () {
      const a = Money(1000, 'BRL');
      const b = Money(250, 'BRL');

      expect(a + b, const Money(1250, 'BRL'));
      expect(a - b, const Money(750, 'BRL'));
      expect(b - a, const Money(-750, 'BRL'));
    });

    test('refuses to mix currencies', () {
      const a = Money(1000, 'BRL');
      const b = Money(1000, 'USD');

      expect(() => a + b, throwsArgumentError);
      expect(() => a - b, throwsArgumentError);
      expect(() => a.compareTo(b), throwsArgumentError);
    });

    test('compares amounts and reports sign', () {
      const small = Money(100, 'BRL');
      const big = Money(200, 'BRL');

      expect(small.compareTo(big), lessThan(0));
      expect(big.compareTo(small), greaterThan(0));
      expect(const Money(-1, 'BRL').isNegative, isTrue);
      expect(const Money.zero('BRL').isZero, isTrue);
    });
  });
}