/// "02/10/2026".
String formatDateBr(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

/// "Hoje", "Ontem" or the date. Compares calendar days, not 24-hour spans,
/// so a late-night entry is still "Ontem" the next morning.
String dayLabel(DateTime date, DateTime now) {
  final today = DateTime.utc(now.year, now.month, now.day);
  final day = DateTime.utc(date.year, date.month, date.day);
  final difference = today.difference(day).inDays;

  if (difference == 0) return 'Hoje';
  if (difference == 1) return 'Ontem';
  return formatDateBr(date);
}