import 'package:finly/features/yield_simulator/domain/yield_form.dart';
import 'package:finly/features/yield_simulator/domain/yield_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  YieldFormParse parse({
    String initial = '10000,00',
    String monthly = '500,00',
    String months = '60',
    RateMode mode = RateMode.cdi,
    String cdi = '13,65',
    String share = '100',
    String fixed = '12',
    TaxMode tax = TaxMode.regressive,
  }) {
    return parseYieldForm(
      initialText: initial,
      monthlyText: monthly,
      monthsText: months,
      mode: mode,
      cdiText: cdi,
      cdiShareText: share,
      fixedText: fixed,
      taxMode: tax,
    );
  }

  test('reads the starting values of the screen', () {
    final result = parse();

    expect(result.errors, isEmpty);
    final input = result.input!;
    expect(input.initialCents, 1000000);
    expect(input.monthlyCents, 50000);
    expect(input.months, 60);
    expect(input.annualRateBps, 1365);
    expect(input.taxMode, TaxMode.regressive);
  });

  group('the money fields', () {
    test('an empty first deposit is zero when there is a monthly deposit', () {
      final result = parse(initial: '');

      expect(result.input!.initialCents, 0);
      expect(result.errors, isEmpty);
    });

    test('an empty monthly deposit is zero when there is a first deposit', () {
      final result = parse(monthly: '  ');

      expect(result.input!.monthlyCents, 0);
    });

    test('both empty asks for one of them', () {
      final result = parse(initial: '', monthly: '');

      expect(result.input, isNull);
      expect(result.errors[YieldField.initial], 'Informe um valor inicial ou um aporte mensal.');
    });

    test('both zero asks for one of them too', () {
      final result = parse(initial: '0', monthly: '0,00');

      expect(result.input, isNull);
      expect(result.errors.containsKey(YieldField.initial), isTrue);
    });

    test('text that is not a value is refused, in its own field', () {
      expect(parse(initial: 'abc').errors.keys, [YieldField.initial]);
      expect(parse(monthly: 'abc').errors.keys, [YieldField.monthly]);
    });

    test('a negative value is refused', () {
      expect(parse(initial: '-100').errors.containsKey(YieldField.initial), isTrue);
    });

    test('more than 10 million reais is refused', () {
      final result = parse(initial: '10000000,01');

      expect(result.input, isNull);
      expect(result.errors[YieldField.initial], contains('máximo'));
    });

    test('exactly 10 million reais is accepted', () {
      final result = parse(initial: '10000000,00', monthly: '0', months: '12');

      expect(result.input, isNotNull);
    });
  });

  group('the term', () {
    test('1 to 600 months are accepted', () {
      expect(parse(months: '1').input, isNotNull);
      expect(parse(months: '600').input, isNotNull);
    });

    test('anything else is refused', () {
      for (final months in ['0', '601', '-3', 'abc', '', '1,5']) {
        final result = parse(months: months);

        expect(result.input, isNull, reason: months);
        expect(result.errors[YieldField.months], 'Informe de 1 a 600 meses.', reason: months);
      }
    });
  });

  group('the rate', () {
    test('the CDI and its share are turned into one rate', () {
      expect(parse(cdi: '14', share: '110').input!.annualRateBps, 1540);
      expect(parse(cdi: '13,65', share: '90').input!.annualRateBps, 1229);
    });

    test('a missing CDI or share is refused, each in its own field', () {
      expect(parse(cdi: '').errors.keys, [YieldField.cdi]);
      expect(parse(share: '').errors.keys, [YieldField.cdiShare]);
      expect(parse(cdi: '', share: '').errors.keys, containsAll([YieldField.cdi, YieldField.cdiShare]));
    });

    test('a share of up to 500% of the CDI is read', () {
      final result = parse(cdi: '10', share: '500');

      expect(result.errors, isEmpty);
      expect(result.input!.annualRateBps, 5000);
    });

    test('a share above 500% is refused', () {
      final result = parse(cdi: '10', share: '501');

      expect(result.input, isNull);
      expect(result.errors.keys, [YieldField.cdiShare]);
    });

    test('a rate above 100% a year is refused', () {
      final result = parse(cdi: '100', share: '200');

      expect(result.input, isNull);
      expect(result.errors[YieldField.cdiShare], 'A taxa efetiva passa de 100% ao ano.');
    });

    test('a fixed rate is read, and the CDI fields are then ignored', () {
      final result = parse(mode: RateMode.fixed, fixed: '12', cdi: 'lixo', share: 'lixo');

      expect(result.errors, isEmpty);
      expect(result.input!.annualRateBps, 1200);
    });

    test('a fixed rate of zero is accepted', () {
      expect(parse(mode: RateMode.fixed, fixed: '0').input!.annualRateBps, 0);
    });

    test('a missing or too high fixed rate is refused', () {
      expect(parse(mode: RateMode.fixed, fixed: '').errors.keys, [YieldField.fixedRate]);
      expect(parse(mode: RateMode.fixed, fixed: '101').errors.keys, [YieldField.fixedRate]);
    });

    test('the fixed field is ignored while the CDI is used', () {
      final result = parse(fixed: 'lixo');

      expect(result.errors, isEmpty);
    });
  });

  test('the tax mode goes through', () {
    expect(parse(tax: TaxMode.exempt).input!.taxMode, TaxMode.exempt);
  });

  test('numbers too large for a sensible result are refused as a whole', () {
    final result = parse(
      initial: '10000000,00',
      monthly: '10000000,00',
      months: '600',
      mode: RateMode.fixed,
      fixed: '100',
    );

    expect(result.input, isNull);
    expect(result.errors[YieldField.result], 'Esses valores dão um resultado grande demais.');
  });

  test('every error is about a field of the form', () {
    final result = parse(initial: 'x', monthly: 'y', months: 'z', cdi: 'a', share: 'b');

    expect(
      result.errors.keys,
      containsAll([
        YieldField.initial,
        YieldField.monthly,
        YieldField.months,
        YieldField.cdi,
        YieldField.cdiShare,
      ]),
    );
    expect(result.input, isNull);
  });
}
