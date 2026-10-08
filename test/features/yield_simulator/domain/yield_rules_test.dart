import 'dart:math' as math;

import 'package:finly/features/yield_simulator/domain/yield_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  YieldInput input({
    int initial = 0,
    int monthly = 0,
    int months = 12,
    int rate = 1200,
    TaxMode tax = TaxMode.regressive,
  }) {
    return YieldInput(
      initialCents: initial,
      monthlyCents: monthly,
      months: months,
      annualRateBps: rate,
      taxMode: tax,
    );
  }

  YieldResult simulate(YieldInput value) => simulateYield(value)!;

  group('regressiveTaxBps', () {
    test('22,5% up to 180 days', () {
      expect(regressiveTaxBps(0), 2250);
      expect(regressiveTaxBps(180), 2250);
    });

    test('20% from 181 to 360 days', () {
      expect(regressiveTaxBps(181), 2000);
      expect(regressiveTaxBps(360), 2000);
    });

    test('17,5% from 361 to 720 days', () {
      expect(regressiveTaxBps(361), 1750);
      expect(regressiveTaxBps(720), 1750);
    });

    test('15% above 720 days', () {
      expect(regressiveTaxBps(721), 1500);
      expect(regressiveTaxBps(3650), 1500);
    });
  });

  group('daysForMonths', () {
    test('a year is 365 days', () {
      expect(daysForMonths(12), 365);
      expect(daysForMonths(24), 730);
      expect(daysForMonths(36), 1095);
    });

    test('six months are a little over 180 days', () {
      expect(daysForMonths(6), 183);
    });

    test('one month is about 30 days', () {
      expect(daysForMonths(1), 30);
    });
  });

  group('annualRateBps', () {
    test('100% of the CDI is the CDI', () {
      expect(annualRateBps(mode: RateMode.cdi, cdiBps: 1365, cdiShareBps: 10000), 1365);
    });

    test('a share above 100% of the CDI rounds to the nearest basis point', () {
      expect(annualRateBps(mode: RateMode.cdi, cdiBps: 1365, cdiShareBps: 11000), 1502);
    });

    test('a share below 100% of the CDI', () {
      expect(annualRateBps(mode: RateMode.cdi, cdiBps: 1400, cdiShareBps: 9000), 1260);
    });

    test('a fixed rate is used as it is', () {
      expect(annualRateBps(mode: RateMode.fixed, fixedBps: 1200), 1200);
    });
  });

  test('ratePercentText writes a rate with a decimal comma', () {
    expect(ratePercentText(1365), '13,65%');
    expect(ratePercentText(1200), '12%');
    expect(ratePercentText(1250), '12,5%');
    expect(ratePercentText(5), '0,05%');
  });

  group('simulateYield', () {
    test('12% a year on 1.000,00 for a year gives 1.120,00 before the tax', () {
      final result = simulate(input(initial: 100000));

      expect(result.grossCents, 112000);
      expect(result.investedCents, 100000);
      expect(result.grossProfitCents, 12000);
    });

    test('the income tax of a year is 17,5% of the profit', () {
      final result = simulate(input(initial: 100000));

      expect(result.taxCents, 2100);
      expect(result.netCents, 109900);
      expect(result.netProfitCents, 9900);
    });

    test('an exempt investment pays no tax', () {
      final result = simulate(input(initial: 100000, tax: TaxMode.exempt));

      expect(result.taxCents, 0);
      expect(result.netCents, result.grossCents);
    });

    test('the tax rate falls with the time: 20% for six months', () {
      final result = simulate(input(initial: 100000, months: 6));
      final profit = 100000 * (math.pow(1.12, 0.5) - 1);

      expect(result.taxCents, (profit * 0.20).round());
    });

    test('the tax rate falls with the time: 15% for three years', () {
      final result = simulate(input(initial: 100000, months: 36));
      final profit = 100000 * (math.pow(1.12, 3) - 1);

      expect(result.taxCents, closeTo(profit * 0.15, 1));
    });

    test('without a rate the money only piles up', () {
      final result = simulate(input(monthly: 10000, rate: 0));

      expect(result.grossCents, 120000);
      expect(result.investedCents, 120000);
      expect(result.taxCents, 0);
      expect(result.netCents, 120000);
    });

    test('a first deposit and monthly deposits, with no rate', () {
      final result = simulate(input(initial: 50000, monthly: 10000, months: 24, rate: 0));

      expect(result.investedCents, 50000 + 10000 * 24);
      expect(result.grossCents, result.investedCents);
    });

    test('matches a month-by-month calculation', () {
      const initial = 500000;
      const monthly = 30000;
      final factor = math.pow(1.1365, 1 / 12).toDouble();
      var balance = initial.toDouble();
      for (var month = 1; month <= 36; month++) {
        balance = balance * factor + monthly;
      }

      final result = simulate(input(initial: initial, monthly: monthly, months: 36, rate: 1365));

      expect(result.grossCents, closeTo(balance.round(), 1));
      expect(result.investedCents, initial + monthly * 36);
    });

    test('a deposit made at the end of a month does not earn in that month', () {
      final factor = math.pow(1.12, 1 / 12).toDouble();
      final result = simulate(input(initial: 100000, monthly: 5000, months: 1));

      expect(result.grossCents, (100000 * factor + 5000).round());
    });

    test('works out the tax deposit by deposit, each with its own time', () {
      final factor = math.pow(1.12, 1 / 12).toDouble();
      var expected = 0.0;
      for (var j = 1; j < 24; j++) {
        final months = 24 - j;
        final profit = 100000 * (math.pow(factor, months) - 1);
        final days = (months * 365 / 12).round();
        final rate = days <= 180 ? 0.225 : days <= 360 ? 0.20 : days <= 720 ? 0.175 : 0.15;
        expected += profit * rate;
      }

      final result = simulate(input(monthly: 100000, months: 24));

      expect(result.taxCents, closeTo(expected.round(), 1));
    });

    test('later deposits pay a lower tax than one rate for everything would', () {
      final result = simulate(input(monthly: 100000, months: 24));
      final allAtTheLowestRate = (result.grossProfitCents * 0.15).round();
      final allAtTheHighestRate = (result.grossProfitCents * 0.225).round();

      expect(result.taxCents, greaterThan(allAtTheLowestRate));
      expect(result.taxCents, lessThan(allAtTheHighestRate));
    });

    test('the tax is never more than the profit', () {
      final result = simulate(input(initial: 1, months: 1, rate: 1));

      expect(result.taxCents, lessThanOrEqualTo(result.grossProfitCents));
      expect(result.taxCents, greaterThanOrEqualTo(0));
    });

    test('has a point for every month, from the start', () {
      final result = simulate(input(initial: 100000, monthly: 5000, months: 36));

      expect(result.points, hasLength(37));
      expect(result.points.first.month, 0);
      expect(result.points.first.investedCents, 100000);
      expect(result.points.first.balanceCents, 100000);
      expect(result.points.last.month, 36);
      expect(result.points.last.balanceCents, result.grossCents);
      expect(result.points.last.investedCents, result.investedCents);
    });

    test('the balance grows every month when there is a rate', () {
      final result = simulate(input(initial: 100000, monthly: 5000, months: 60));

      for (var i = 1; i < result.points.length; i++) {
        expect(result.points[i].balanceCents, greaterThan(result.points[i - 1].balanceCents));
      }
    });

    test('the balance never falls below what was put in', () {
      final result = simulate(input(initial: 100000, monthly: 5000, months: 60, rate: 500));

      for (final point in result.points) {
        expect(point.balanceCents, greaterThanOrEqualTo(point.investedCents));
      }
    });

    test('a longer term gives a bigger result', () {
      final short = simulate(input(initial: 100000, months: 12));
      final long = simulate(input(initial: 100000, months: 60));

      expect(long.netCents, greaterThan(short.netCents));
    });

    test('a higher rate gives a bigger result', () {
      final low = simulate(input(initial: 100000, rate: 800));
      final high = simulate(input(initial: 100000, rate: 1400));

      expect(high.grossCents, greaterThan(low.grossCents));
    });

    test('the longest term of 50 years works', () {
      final result = simulate(input(initial: 100000, monthly: 50000, months: maxYieldMonths, rate: 1000));

      expect(result.points, hasLength(maxYieldMonths + 1));
      expect(result.grossCents, greaterThan(result.investedCents));
    });

    test('numbers too large to be sensible give no result', () {
      final result = simulateYield(input(
        initial: 1000000000,
        monthly: 1000000000,
        months: maxYieldMonths,
        rate: maxAnnualRateBps,
      ));

      expect(result, isNull);
    });

    test('a rate of zero and a rate of nearly zero both work', () {
      expect(simulateYield(input(initial: 100000, rate: 0)), isNotNull);
      expect(simulateYield(input(initial: 100000, rate: 1)), isNotNull);
    });
  });
}
