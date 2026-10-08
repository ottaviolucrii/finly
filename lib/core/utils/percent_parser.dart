/// Reads what a person typed as a percentage ("6", "13,65", "6.5", " 7 % ") as
/// basis points (100 basis points = 1%): "13,65" is 1365. Null for anything
/// else: empty, letters, more than two decimals, a negative value, or above
/// [maxBps].
int? parseBps(String input, {required int maxBps}) {
  var text = input.trim();
  if (text.endsWith('%')) text = text.substring(0, text.length - 1).trim();
  text = text.replaceAll(',', '.');

  final match = RegExp(r'^(\d{1,4})(?:\.(\d{1,2}))?$').firstMatch(text);
  if (match == null) return null;

  final whole = int.parse(match.group(1)!);
  final fraction = int.parse((match.group(2) ?? '').padRight(2, '0'));
  final bps = whole * 100 + fraction;

  return bps > maxBps ? null : bps;
}
