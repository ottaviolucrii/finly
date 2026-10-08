import 'dart:math' as math;

/// How the rate of the investment is given.
enum RateMode {
  /// A share of the CDI ("110% of the CDI").
  cdi,

  /// A fixed rate per year ("12% a year").
  fixed,
}

/// How the income tax is charged on the profit.
enum TaxMode {
  /// The regressive table of fixed income (CDB, Tesouro): the longer the money
  /// stays, the lower the rate, from 22.5% down to 15%.
  regressive,

  /// No income tax (LCI, LCA, poupança).
  exempt,
}

/// The longest term the simulator accepts: 50 years.
const int maxYieldMonths = 600;

/// The highest rate per year the simulator accepts: 100%.
const int maxAnnualRateBps = 10000;

/// A result above this many cents (about 90 trillion reais) is refused: it is
/// not a sensible simulation and it would not fit the numbers of the app.
const double _maxResultCents = 9e15;

class YieldInput {
  /// What is invested on day one.
  final int initialCents;

  /// What is added at the end of each month.
  final int monthlyCents;

  final int months;

  /// The effective rate per year, in basis points (1365 = 13.65%).
  final int annualRateBps;

  final TaxMode taxMode;

  const YieldInput({
    required this.initialCents,
    required this.monthlyCents,
    required this.months,
    required this.annualRateBps,
    required this.taxMode,
  });
}

/// The state of the investment at the end of one month.
class YieldPoint {
  final int month;

  /// What the person put in until then.
  final int investedCents;

  /// What it is worth, before the income tax.
  final int balanceCents;

  const YieldPoint({
    required this.month,
    required this.investedCents,
    required this.balanceCents,
  });
}

class YieldResult {
  final YieldInput input;

  /// Month 0 (the start) to the last month.
  final List<YieldPoint> points;

  /// Everything the person put in.
  final int investedCents;

  /// What it is worth at the end, before the income tax.
  final int grossCents;

  /// The income tax on the profit (0 when exempt).
  final int taxCents;

  const YieldResult({
    required this.input,
    required this.points,
    required this.investedCents,
    required this.grossCents,
    required this.taxCents,
  });

  int get grossProfitCents => grossCents - investedCents;

  /// What the person receives, after the income tax.
  int get netCents => grossCents - taxCents;

  int get netProfitCents => netCents - investedCents;
}

/// "13,65%" or "12%": a rate in basis points, with a decimal comma and no
/// trailing zeros.
String ratePercentText(int bps) {
  final whole = bps ~/ 100;
  final fraction = bps % 100;
  if (fraction == 0) return '$whole%';

  var digits = fraction.toString().padLeft(2, '0');
  if (digits.endsWith('0')) digits = digits.substring(0, 1);
  return '$whole,$digits%';
}

/// The income tax rate for money that stayed [days] days, in basis points.
int regressiveTaxBps(int days) {
  if (days <= 180) return 2250;
  if (days <= 360) return 2000;
  if (days <= 720) return 1750;
  return 1500;
}

/// How many days [months] months are, for the table of the income tax.
int daysForMonths(int months) => (months * 365 / 12).round();

/// The effective rate per year, in basis points. With the CDI it is the CDI
/// times the share of it (1365 and 11000, that is 110%, give 1502).
int annualRateBps({
  required RateMode mode,
  int cdiBps = 0,
  int cdiShareBps = 0,
  int fixedBps = 0,
}) {
  switch (mode) {
    case RateMode.cdi:
      return (cdiBps * cdiShareBps + 5000) ~/ 10000;
    case RateMode.fixed:
      return fixedBps;
  }
}

/// How an investment grows: a first deposit, a deposit at the end of every
/// month, and a constant rate per year turned into a monthly one. Interest is
/// compounded every month. The income tax (when there is one) is worked out
/// deposit by deposit, because each one stayed a different time: the first
/// deposit all the months, the last one not at all.
///
/// Returns null when the numbers are so large that the result is not
/// sensible.
YieldResult? simulateYield(YieldInput input) {
  assert(input.months >= 1);
  final annual = input.annualRateBps / 10000;
  final factor = math.pow(1 + annual, 1 / 12).toDouble();
  final flat = (factor - 1).abs() < 1e-15;

  // How much one cent grows in k months.
  double growth(int k) => flat ? 1 : math.pow(factor, k).toDouble();

  // The value after k months: the first deposit grown k months, plus each
  // deposit j (made at the end of month j) grown for the k - j months since.
  double valueAt(int k) {
    final sumOfGrowth = flat ? k.toDouble() : (growth(k) - 1) / (factor - 1);
    return input.initialCents * growth(k) + input.monthlyCents * sumOfGrowth;
  }

  final finalValue = valueAt(input.months);
  if (!finalValue.isFinite || finalValue > _maxResultCents) return null;

  final points = <YieldPoint>[
    for (var k = 0; k <= input.months; k++)
      YieldPoint(
        month: k,
        investedCents: input.initialCents + input.monthlyCents * k,
        balanceCents: valueAt(k).round(),
      ),
  ];

  final invested = points.last.investedCents;
  final gross = points.last.balanceCents;

  var tax = 0.0;
  if (input.taxMode == TaxMode.regressive) {
    void addLot(int cents, int months) {
      if (cents <= 0 || months <= 0) return;
      final profit = cents * (growth(months) - 1);
      tax += profit * regressiveTaxBps(daysForMonths(months)) / 10000;
    }

    addLot(input.initialCents, input.months);
    for (var j = 1; j < input.months; j++) {
      addLot(input.monthlyCents, input.months - j);
    }
  }

  final profit = gross - invested;
  final taxCents = profit <= 0 ? 0 : math.min(tax.round(), profit);

  return YieldResult(
    input: input,
    points: points,
    investedCents: invested,
    grossCents: gross,
    taxCents: taxCents,
  );
}
