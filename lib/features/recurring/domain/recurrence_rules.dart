import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';

/// The date of occurrence number [n] (0 is the first, on [start]). It mirrors
/// the database function `private.recurrence_date`: months and years are
/// counted from [start], so a monthly bill that starts on the 31st falls on
/// the last day of shorter months and goes back to the 31st afterwards.
DateTime recurrenceDate(
  DateTime start,
  RecurrenceFrequency frequency,
  int intervalCount,
  int n,
) {
  switch (frequency) {
    case RecurrenceFrequency.daily:
      return DateTime(start.year, start.month, start.day + n * intervalCount);
    case RecurrenceFrequency.weekly:
      return DateTime(
        start.year,
        start.month,
        start.day + n * intervalCount * 7,
      );
    case RecurrenceFrequency.monthly:
      return _addMonths(start, n * intervalCount);
    case RecurrenceFrequency.yearly:
      return _addMonths(start, 12 * n * intervalCount);
  }
}

DateTime _addMonths(DateTime date, int months) {
  final firstOfTarget = DateTime(date.year, date.month + months);
  final lastDay = DateTime(firstOfTarget.year, firstOfTarget.month + 1, 0).day;
  return DateTime(
    firstOfTarget.year,
    firstOfTarget.month,
    date.day > lastDay ? lastDay : date.day,
  );
}

/// The first occurrence on or after [today], or null when the series has
/// ended (the next date would be after [endDate]).
DateTime? nextOccurrence({
  required DateTime start,
  required RecurrenceFrequency frequency,
  required int intervalCount,
  DateTime? endDate,
  required DateTime today,
}) {
  final day = DateTime(today.year, today.month, today.day);
  final last =
      endDate == null ? null : DateTime(endDate.year, endDate.month, endDate.day);

  for (var n = 0; n < 20000; n++) {
    final date = recurrenceDate(start, frequency, intervalCount, n);
    if (last != null && date.isAfter(last)) return null;
    if (!date.isBefore(day)) return date;
  }
  return null;
}