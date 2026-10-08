/// The most the reserve can be: all of the income (10000 basis points).
const int maxPercentBps = 10000;

/// [incomeCents] times [percentBps] basis points, rounded to the nearest cent
/// (halves go up). An income that is zero or negative reserves nothing.
int reserveFor(int incomeCents, int percentBps) {
  if (incomeCents <= 0 || percentBps <= 0) return 0;
  return (incomeCents * percentBps + 5000) ~/ 10000;
}

/// "6%", "6,5%", "6,25%": basis points as a percentage, with a decimal comma
/// and no trailing zeros.
String percentText(int bps) {
  final whole = bps ~/ 100;
  final fraction = bps % 100;
  if (fraction == 0) return '$whole%';

  var digits = fraction.toString().padLeft(2, '0');
  if (digits.endsWith('0')) digits = digits.substring(0, 1);
  return '$whole,$digits%';
}

/// The same percentage without the sign, to fill a text field: "6,5".
String percentInput(int bps) => percentText(bps).replaceAll('%', '');

/// Reads what a person typed ("6", "6,5", "6.25", " 7 % ") as basis points.
/// Null for anything else: empty, letters, more than two decimals, negative, or
/// above 100.
int? parsePercentToBps(String input) {
  var text = input.trim();
  if (text.endsWith('%')) text = text.substring(0, text.length - 1).trim();
  text = text.replaceAll(',', '.');

  final match = RegExp(r'^(\d{1,3})(?:\.(\d{1,2}))?$').firstMatch(text);
  if (match == null) return null;

  final whole = int.parse(match.group(1)!);
  final fraction = int.parse((match.group(2) ?? '').padRight(2, '0').padLeft(2, '0'));
  final bps = whole * 100 + fraction;

  return bps > maxPercentBps ? null : bps;
}
