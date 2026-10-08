import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/percent_parser.dart';
import 'package:finly/features/yield_simulator/domain/yield_rules.dart';

/// The fields of the simulator, to say which one an error is about.
enum YieldField { initial, monthly, months, cdi, cdiShare, fixedRate, result }

class YieldFormParse {
  /// The numbers to simulate, or null while something is missing or wrong.
  final YieldInput? input;

  /// What is wrong, by field, in words for the person.
  final Map<YieldField, String> errors;

  const YieldFormParse({this.input, this.errors = const {}});
}

/// The most that can be typed in a money field: 10 million reais.
const int _maxMoneyCents = 1000000000;

/// The highest share of the CDI: 500%.
const int _maxCdiShareBps = 50000;

/// The highest CDI that is accepted: 100%.
const int _maxCdiBps = 10000;

/// Reads the texts of the simulator. An empty first deposit or monthly deposit
/// is zero (but not both); the other fields are needed.
YieldFormParse parseYieldForm({
  required String initialText,
  required String monthlyText,
  required String monthsText,
  required RateMode mode,
  required String cdiText,
  required String cdiShareText,
  required String fixedText,
  required TaxMode taxMode,
}) {
  final errors = <YieldField, String>{};

  int? money(String text, YieldField field) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;

    final parsed = Money.tryParse(trimmed, 'BRL');
    if (parsed == null || parsed.cents < 0) {
      errors[field] = 'Informe um valor válido (ex.: 1000,00).';
      return null;
    }
    if (parsed.cents > _maxMoneyCents) {
      errors[field] = 'O valor máximo é R\$ 10.000.000,00.';
      return null;
    }
    return parsed.cents;
  }

  final initial = money(initialText, YieldField.initial);
  final monthly = money(monthlyText, YieldField.monthly);
  if (initial != null && monthly != null && initial == 0 && monthly == 0) {
    errors[YieldField.initial] = 'Informe um valor inicial ou um aporte mensal.';
  }

  final months = int.tryParse(monthsText.trim());
  if (months == null || months < 1 || months > maxYieldMonths) {
    errors[YieldField.months] = 'Informe de 1 a $maxYieldMonths meses.';
  }

  int? rate;
  switch (mode) {
    case RateMode.cdi:
      final cdi = parseBps(cdiText, maxBps: _maxCdiBps);
      final share = parseBps(cdiShareText, maxBps: _maxCdiShareBps);
      if (cdi == null) errors[YieldField.cdi] = 'Informe o CDI (ex.: 13,65).';
      if (share == null) {
        errors[YieldField.cdiShare] = 'Informe a porcentagem do CDI (ex.: 100).';
      }
      if (cdi != null && share != null) {
        rate = annualRateBps(mode: mode, cdiBps: cdi, cdiShareBps: share);
      }
    case RateMode.fixed:
      final fixed = parseBps(fixedText, maxBps: maxAnnualRateBps);
      if (fixed == null) {
        errors[YieldField.fixedRate] = 'Informe a taxa ao ano (ex.: 12).';
      } else {
        rate = annualRateBps(mode: mode, fixedBps: fixed);
      }
  }

  if (rate != null && rate > maxAnnualRateBps) {
    final field = mode == RateMode.cdi ? YieldField.cdiShare : YieldField.fixedRate;
    errors[field] = 'A taxa efetiva passa de 100% ao ano.';
    rate = null;
  }

  if (errors.isNotEmpty || initial == null || monthly == null || months == null || rate == null) {
    return YieldFormParse(errors: errors);
  }

  final input = YieldInput(
    initialCents: initial,
    monthlyCents: monthly,
    months: months,
    annualRateBps: rate,
    taxMode: taxMode,
  );

  if (simulateYield(input) == null) {
    return const YieldFormParse(
      errors: {YieldField.result: 'Esses valores dão um resultado grande demais.'},
    );
  }
  return YieldFormParse(input: input);
}
