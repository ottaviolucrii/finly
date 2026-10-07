import 'package:finly/features/dashboard/domain/dashboard_rules.dart';
import 'package:finly/features/forecast/domain/entities/forecast_items.dart';

/// How far ahead the forecast looks.
const int forecastMaxDays = 90;

/// The longest series of occurrences looked at for one recurring item.
const int _maxOccurrences = 500;

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Whole days from [from] to [to] (both date only).
int dayIndex(DateTime from, DateTime to) {
  return DateTime.utc(to.year, to.month, to.day)
      .difference(DateTime.utc(from.year, from.month, from.day))
      .inDays;
}

/// [date] moved by [months], like PostgreSQL does: the day of the month stays,
/// unless the new month is shorter, and then it is the last day (Jan 31 + 1
/// month = Feb 28 or 29).
DateTime addMonthsClamped(DateTime date, int months) {
  final total = date.year * 12 + (date.month - 1) + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;

  return DateTime(year, month, date.day > lastDay ? lastDay : date.day);
}

/// The date of occurrence number [n] (from 0) of a recurring item. The same
/// rule as `private.recurrence_date` in the database: every date is counted
/// from the start date, never from the previous occurrence.
DateTime recurrenceDate(
  DateTime start,
  ForecastFrequency frequency,
  int interval,
  int n,
) {
  switch (frequency) {
    case ForecastFrequency.daily:
      return DateTime(start.year, start.month, start.day + n * interval);
    case ForecastFrequency.weekly:
      return DateTime(start.year, start.month, start.day + n * interval * 7);
    case ForecastFrequency.monthly:
      return addMonthsClamped(start, n * interval);
    case ForecastFrequency.yearly:
      return addMonthsClamped(start, 12 * n * interval);
  }
}

/// The days a recurring item will still have an occurrence, up to [until]
/// (included). The database has already generated the first
/// `generatedCount` occurrences (they are pending transactions, counted
/// elsewhere), so only the next ones are listed here. As the database does,
/// occurrences before the day the item was created are skipped and the item
/// stops at its end date. One that is already in the past would be generated
/// as overdue, so it counts today.
List<DateTime> projectRecurring(
  RecurringTemplate template, {
  required DateTime today,
  required DateTime until,
}) {
  final first = dateOnly(today);
  final dates = <DateTime>[];
  var n = template.generatedCount;

  for (var step = 0; step < _maxOccurrences; step++, n++) {
    final date = recurrenceDate(
      template.startDate,
      template.frequency,
      template.intervalCount,
      n,
    );
    if (date.isAfter(until)) break;
    final end = template.endDate;
    if (end != null && date.isAfter(end)) break;
    if (date.isBefore(template.createdOn)) continue;

    dates.add(date.isBefore(first) ? first : date);
  }
  return dates;
}

/// The balance of one currency day by day for [days] days after [today], and
/// the movements behind it. A movement dated before today (an overdue bill)
/// counts today; one after the last day is left out. [items] must all be in
/// [currency].
Forecast buildForecast({
  required String currency,
  required int startCents,
  required List<ForecastItem> items,
  required DateTime today,
  required int days,
}) {
  assert(days >= 0);
  final first = dateOnly(today);
  final netByDay = List<int>.filled(days + 1, 0);
  final inRange = <ForecastItem>[];

  for (final item in items) {
    var day = dateOnly(item.date);
    if (day.isBefore(first)) day = first;

    final index = dayIndex(first, day);
    if (index > days) continue;

    netByDay[index] += item.amountCents;
    inRange.add(item.movedTo(day));
  }

  final points = <ForecastPoint>[];
  var balance = startCents;
  for (var i = 0; i <= days; i++) {
    balance += netByDay[i];
    points.add(
      ForecastPoint(
        date: DateTime(first.year, first.month, first.day + i),
        balanceCents: balance,
      ),
    );
  }

  // Money going out first inside a day: the balance is never shown better than
  // it can be.
  inRange.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    final byAmount = a.amountCents.compareTo(b.amountCents);
    return byAmount != 0 ? byAmount : a.label.compareTo(b.label);
  });

  var running = startCents;
  final events = <ForecastEvent>[];
  for (final item in inRange) {
    running += item.amountCents;
    events.add(ForecastEvent(item: item, balanceAfterCents: running));
  }

  return Forecast(
    currency: currency,
    startCents: startCents,
    points: points,
    events: events,
  );
}

/// One forecast per currency that has an account or a movement, BRL first.
List<Forecast> buildForecasts(
  ForecastInputs inputs, {
  required DateTime today,
  int days = forecastMaxDays,
}) {
  final last = DateTime(today.year, today.month, today.day + days);
  final itemsByCurrency = <String, List<ForecastItem>>{};

  void add(ForecastItem item) {
    itemsByCurrency.putIfAbsent(item.currency, () => []).add(item);
  }

  for (final flow in inputs.pending) {
    add(
      ForecastItem(
        kind: ForecastKind.pending,
        label: flow.description,
        amountCents: flow.isIncome ? flow.amountCents : -flow.amountCents,
        currency: flow.currency,
        date: flow.date,
      ),
    );
  }

  for (final template in inputs.recurring) {
    for (final date in projectRecurring(template, today: today, until: last)) {
      add(
        ForecastItem(
          kind: ForecastKind.recurring,
          label: template.description,
          amountCents: template.isIncome ? template.amountCents : -template.amountCents,
          currency: template.currency,
          date: date,
        ),
      );
    }
  }

  for (final invoice in inputs.invoices) {
    if (invoice.totalCents <= 0) continue;
    add(
      ForecastItem(
        kind: ForecastKind.invoice,
        label: invoice.cardName,
        amountCents: -invoice.totalCents,
        currency: invoice.currency,
        date: invoice.dueDate,
      ),
    );
  }

  final currencies = sortCurrencies([
    ...inputs.startingBalances.keys,
    ...itemsByCurrency.keys,
  ]);

  return [
    for (final currency in currencies)
      buildForecast(
        currency: currency,
        startCents: inputs.startingBalances[currency] ?? 0,
        items: itemsByCurrency[currency] ?? const [],
        today: today,
        days: days,
      ),
  ];
}
