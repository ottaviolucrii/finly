/// "2026-03-05": the format the database uses for a date, with no time and no
/// time zone. The year is padded to four digits.
String isoDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// Reads "2026-03-05" (or a timestamp that starts with it) as that day, with
/// no time zone involved. Throws a [FormatException] for anything else.
DateTime parseIsoDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  if (match == null) throw FormatException('Not an ISO date: $value');

  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}
