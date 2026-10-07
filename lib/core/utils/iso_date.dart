/// "2026-03-05": the format the database uses for a date, with no time and no
/// time zone. The year is padded to four digits.
String isoDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
