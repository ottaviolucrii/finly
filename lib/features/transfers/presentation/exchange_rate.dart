/// A readable exchange rate for a transfer between currencies, for example
/// "Câmbio: 1 USD = 5,26 BRL". For display only: the two amounts the user
/// typed are what gets saved. Returns null when an amount is not above zero.
String? exchangeRateLabel({
  required String fromCurrency,
  required String toCurrency,
  required int fromCents,
  required int toCents,
}) {
  if (fromCents <= 0 || toCents <= 0) return null;

  // Units of the origin currency for one unit of the destination currency.
  final ratio = fromCents / toCents;
  if (ratio >= 1) {
    return 'Câmbio: 1 $toCurrency = ${_format(ratio)} $fromCurrency';
  }
  return 'Câmbio: 1 $fromCurrency = ${_format(1 / ratio)} $toCurrency';
}

String _format(double value) => value.toStringAsFixed(2).replaceAll('.', ',');