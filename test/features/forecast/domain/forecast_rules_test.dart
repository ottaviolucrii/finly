import 'package:finly/features/forecast/domain/entities/forecast_items.dart';
import 'package:finly/features/forecast/domain/forecast_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A Tuesday.
  final today = DateTime(2026, 10, 6);

  ForecastItem item(
    int cents, {
    required DateTime on,
    String label = 'Item',
    ForecastKind kind = ForecastKind.pending,
    String currency = 'BRL',
  }) {
    return ForecastItem(
      kind: kind,
      label: label,
      amountCents: cents,
      currency: currency,
      date: on,
    );
  }

  RecurringTemplate template({
    ForecastFrequency frequency = ForecastFrequency.monthly,
    int interval = 1,
    DateTime? start,
    DateTime? end,
    int generated = 10,
    DateTime? createdOn,
    bool income = false,
    int cents = 150000,
    String currency = 'BRL',
    String description = 'Aluguel',
  }) {
    return RecurringTemplate(
      id: 'r1',
      description: description,
      amountCents: cents,
      currency: currency,
      isIncome: income,
      frequency: frequency,
      intervalCount: interval,
      startDate: start ?? DateTime(2026, 1, 5),
      endDate: end,
      generatedCount: generated,
      createdOn: createdOn ?? DateTime(2026, 1, 1),
    );
  }

  group('addMonthsClamped', () {
    test('keeps the day of the month', () {
      expect(addMonthsClamped(DateTime(2026, 10, 15), 3), DateTime(2027, 1, 15));
      expect(addMonthsClamped(DateTime(2026, 10, 15), 12), DateTime(2027, 10, 15));
    });

    test('goes to the last day when the month is shorter', () {
      expect(addMonthsClamped(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonthsClamped(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
      expect(addMonthsClamped(DateTime(2026, 8, 31), 1), DateTime(2026, 9, 30));
    });

    test('goes back to the day it was when the month is long again', () {
      expect(addMonthsClamped(DateTime(2026, 1, 31), 2), DateTime(2026, 3, 31));
    });

    test('moves backwards too', () {
      expect(addMonthsClamped(DateTime(2026, 3, 31), -1), DateTime(2026, 2, 28));
      expect(addMonthsClamped(DateTime(2026, 1, 10), -2), DateTime(2025, 11, 10));
    });

    test('zero months changes nothing', () {
      expect(addMonthsClamped(DateTime(2026, 10, 6), 0), DateTime(2026, 10, 6));
    });
  });

  group('recurrenceDate', () {
    test('daily counts days from the start', () {
      expect(
        recurrenceDate(DateTime(2026, 10, 1), ForecastFrequency.daily, 3, 2),
        DateTime(2026, 10, 7),
      );
    });

    test('weekly counts weeks from the start', () {
      expect(
        recurrenceDate(DateTime(2026, 10, 1), ForecastFrequency.weekly, 2, 3),
        DateTime(2026, 11, 12),
      );
    });

    test('monthly counts from the start date, never from the previous one', () {
      final start = DateTime(2026, 1, 31);

      expect(recurrenceDate(start, ForecastFrequency.monthly, 1, 1), DateTime(2026, 2, 28));
      expect(recurrenceDate(start, ForecastFrequency.monthly, 1, 2), DateTime(2026, 3, 31));
    });

    test('monthly with an interval of two', () {
      expect(
        recurrenceDate(DateTime(2026, 1, 10), ForecastFrequency.monthly, 2, 3),
        DateTime(2026, 7, 10),
      );
    });

    test('yearly moves by whole years and clamps February 29', () {
      expect(
        recurrenceDate(DateTime(2028, 2, 29), ForecastFrequency.yearly, 1, 1),
        DateTime(2029, 2, 28),
      );
      expect(
        recurrenceDate(DateTime(2028, 2, 29), ForecastFrequency.yearly, 1, 4),
        DateTime(2032, 2, 29),
      );
    });

    test('occurrence 0 is the start date', () {
      for (final frequency in ForecastFrequency.values) {
        expect(
          recurrenceDate(DateTime(2026, 5, 20), frequency, 1, 0),
          DateTime(2026, 5, 20),
        );
      }
    });
  });

  group('projectRecurring', () {
    final until = DateTime(2027, 1, 4); // today + 90 days

    test('lists the occurrences the database has not generated yet', () {
      // Occurrences 0 to 9 (Jan to Oct) exist already; the next is Nov 5.
      final dates = projectRecurring(template(), today: today, until: until);

      expect(dates, [DateTime(2026, 11, 5), DateTime(2026, 12, 5)]);
    });

    test('stops at the end date', () {
      final dates = projectRecurring(
        template(end: DateTime(2026, 11, 20)),
        today: today,
        until: until,
      );

      expect(dates, [DateTime(2026, 11, 5)]);
    });

    test('an end date that is exactly an occurrence still counts it', () {
      final dates = projectRecurring(
        template(end: DateTime(2026, 12, 5)),
        today: today,
        until: until,
      );

      expect(dates, [DateTime(2026, 11, 5), DateTime(2026, 12, 5)]);
    });

    test('skips occurrences before the day the item was created, like the database', () {
      final dates = projectRecurring(
        template(createdOn: DateTime(2026, 11, 10)),
        today: today,
        until: until,
      );

      expect(dates, [DateTime(2026, 12, 5)]);
    });

    test('an occurrence already overdue and not generated counts today', () {
      final dates = projectRecurring(template(generated: 9), today: today, until: until);

      expect(dates, [today, DateTime(2026, 11, 5), DateTime(2026, 12, 5)]);
    });

    test('is empty when the next occurrence is beyond the period', () {
      final dates = projectRecurring(
        template(frequency: ForecastFrequency.yearly, start: DateTime(2026, 3, 1), generated: 1),
        today: today,
        until: until,
      );

      expect(dates, isEmpty);
    });

    test('a weekly item gives one occurrence a week until the end of the period', () {
      final dates = projectRecurring(
        template(
          frequency: ForecastFrequency.weekly,
          start: DateTime(2026, 10, 7),
          generated: 5,
          createdOn: DateTime(2026, 10, 1),
        ),
        today: today,
        until: until,
      );

      // Occurrences 0..4 (Oct 7 to Nov 4) exist; the next is Nov 11.
      expect(dates, [
        DateTime(2026, 11, 11),
        DateTime(2026, 11, 18),
        DateTime(2026, 11, 25),
        DateTime(2026, 12, 2),
        DateTime(2026, 12, 9),
        DateTime(2026, 12, 16),
        DateTime(2026, 12, 23),
        DateTime(2026, 12, 30),
      ]);
    });

    test('never loops forever on a very old item', () {
      final dates = projectRecurring(
        template(
          frequency: ForecastFrequency.daily,
          start: DateTime(2020, 1, 1),
          generated: 0,
          createdOn: DateTime(2020, 1, 1),
        ),
        today: today,
        until: until,
      );

      expect(dates.length, lessThanOrEqualTo(500));
    });
  });

  group('buildForecast', () {
    test('has one point a day, from today', () {
      final forecast = buildForecast(
        currency: 'BRL',
        startCents: 50000,
        items: const [],
        today: today,
        days: 5,
      );

      expect(forecast.points, hasLength(6));
      expect(forecast.points.first.date, today);
      expect(forecast.points.last.date, DateTime(2026, 10, 11));
      expect(forecast.days, 5);
    });

    test('without movements the balance stays where it is', () {
      final forecast = buildForecast(
        currency: 'BRL',
        startCents: 50000,
        items: const [],
        today: today,
        days: 3,
      );

      expect(forecast.points.map((p) => p.balanceCents), [50000, 50000, 50000, 50000]);
      expect(forecast.events, isEmpty);
      expect(forecast.endCents, 50000);
    });

    test('adds each movement on its day', () {
      final forecast = buildForecast(
        currency: 'BRL',
        startCents: 50000,
        items: [
          item(100000, on: DateTime(2026, 10, 8)),
          item(-30000, on: DateTime(2026, 10, 7)),
        ],
        today: today,
        days: 4,
      );

      expect(
        forecast.points.map((p) => p.balanceCents),
        [50000, 20000, 120000, 120000, 120000],
      );
    });

    test('an overdue movement counts today', () {
      final forecast = buildForecast(
        currency: 'BRL',
        startCents: 50000,
        items: [item(-5000, on: DateTime(2026, 10, 1))],
        today: today,
        days: 2,
      );

      expect(forecast.points.first.balanceCents, 45000);
      expect(forecast.events.single.item.date, today);
    });

    test('leaves out what is after the last day', () {
      final forecast = buildForecast(
        currency: 'BRL',
        startCents: 50000,
        items: [item(-5000, on: DateTime(2026, 12, 31))],
        today: today,
        days: 30,
      );

      expect(forecast.events, isEmpty);
      expect(forecast.endCents, 50000);
    });

    test('keeps a movement on the very last day', () {
      final forecast = buildForecast(
        currency: 'BRL',
        startCents: 0,
        items: [item(7000, on: DateTime(2026, 10, 11))],
        today: today,
        days: 5,
      );

      expect(forecast.endCents, 7000);
      expect(forecast.events, hasLength(1));
    });

    test('ignores the time of day of a movement', () {
      final forecast = buildForecast(
        currency: 'BRL',
        startCents: 0,
        items: [item(1000, on: DateTime(2026, 10, 7, 23, 59))],
        today: today,
        days: 2,
      );

      expect(forecast.points.map((p) => p.balanceCents), [0, 1000, 1000]);
    });

    test('lists the events in order with the balance after each one', () {
      final forecast = buildForecast(
        currency: 'BRL',
        startCents: 50000,
        items: [
          item(100000, on: DateTime(2026, 10, 8), label: 'Salário'),
          item(-30000, on: DateTime(2026, 10, 7), label: 'Aluguel'),
          item(-5000, on: DateTime(2026, 10, 1), label: 'Atrasada'),
        ],
        today: today,
        days: 4,
      );

      expect(forecast.events.map((e) => e.item.label), ['Atrasada', 'Aluguel', 'Salário']);
      expect(forecast.events.map((e) => e.balanceAfterCents), [45000, 15000, 115000]);
    });

    test('puts money going out first inside a day', () {
      final forecast = buildForecast(
        currency: 'BRL',
        startCents: 10000,
        items: [
          item(5000, on: DateTime(2026, 10, 7), label: 'Entrada'),
          item(-20000, on: DateTime(2026, 10, 7), label: 'Saída'),
        ],
        today: today,
        days: 2,
      );

      expect(forecast.events.map((e) => e.item.label), ['Saída', 'Entrada']);
      expect(forecast.events.first.balanceAfterCents, -10000);
      expect(forecast.events.last.balanceAfterCents, -5000);
    });

    test('finds the lowest day and the first negative one', () {
      final forecast = buildForecast(
        currency: 'BRL',
        startCents: 10000,
        items: [
          item(-30000, on: DateTime(2026, 10, 7)),
          item(50000, on: DateTime(2026, 10, 9)),
        ],
        today: today,
        days: 4,
      );

      expect(forecast.lowest.balanceCents, -20000);
      expect(forecast.lowest.date, DateTime(2026, 10, 7));
      expect(forecast.firstNegativeDate, DateTime(2026, 10, 7));
    });

    test('the lowest day is the first one when it ties', () {
      final forecast = buildForecast(
        currency: 'BRL',
        startCents: 1000,
        items: [item(-500, on: DateTime(2026, 10, 7))],
        today: today,
        days: 3,
      );

      expect(forecast.lowest.date, DateTime(2026, 10, 7));
    });

    test('has no negative day when the balance stays above zero', () {
      final forecast = buildForecast(
        currency: 'BRL',
        startCents: 50000,
        items: [item(-10000, on: DateTime(2026, 10, 7))],
        today: today,
        days: 3,
      );

      expect(forecast.firstNegativeDate, isNull);
    });

    test('zero is not negative', () {
      final forecast = buildForecast(
        currency: 'BRL',
        startCents: 10000,
        items: [item(-10000, on: DateTime(2026, 10, 7))],
        today: today,
        days: 2,
      );

      expect(forecast.firstNegativeDate, isNull);
    });

    test('a forecast of zero days is a single point', () {
      final forecast = buildForecast(
        currency: 'BRL',
        startCents: 100,
        items: [item(-30, on: today)],
        today: today,
        days: 0,
      );

      expect(forecast.points.single.balanceCents, 70);
    });

    test('ignores the time of day of today', () {
      final forecast = buildForecast(
        currency: 'BRL',
        startCents: 0,
        items: const [],
        today: DateTime(2026, 10, 6, 18, 30),
        days: 1,
      );

      expect(forecast.points.first.date, DateTime(2026, 10, 6));
    });

    test('counts the days across the end of a month', () {
      final forecast = buildForecast(
        currency: 'BRL',
        startCents: 0,
        items: [item(500, on: DateTime(2026, 11, 2))],
        today: DateTime(2026, 10, 30),
        days: 5,
      );

      expect(forecast.points.map((p) => p.balanceCents), [0, 0, 0, 500, 500, 500]);
    });
  });

  group('Forecast.limitTo', () {
    final full = buildForecast(
      currency: 'BRL',
      startCents: 1000,
      items: [
        item(-100, on: DateTime(2026, 10, 8)),
        item(-200, on: DateTime(2026, 10, 12)),
      ],
      today: today,
      days: 10,
    );

    test('cuts the points and the events', () {
      final cut = full.limitTo(3);

      expect(cut.days, 3);
      expect(cut.points, hasLength(4));
      expect(cut.events, hasLength(1));
      expect(cut.endCents, 900);
    });

    test('keeps the starting balance and the currency', () {
      final cut = full.limitTo(3);

      expect(cut.startCents, 1000);
      expect(cut.currency, 'BRL');
    });

    test('a limit longer than the forecast changes nothing', () {
      expect(full.limitTo(99), full);
    });

    test('recomputes the lowest day for the shorter period', () {
      expect(full.lowest.balanceCents, 700);
      expect(full.limitTo(3).lowest.balanceCents, 900);
    });
  });

  group('buildForecasts', () {
    test('is empty when there is nothing', () {
      expect(buildForecasts(const ForecastInputs(), today: today), isEmpty);
    });

    test('starts from the balances and has a forecast for each currency, BRL first', () {
      final result = buildForecasts(
        const ForecastInputs(startingBalances: {'USD': 20000, 'BRL': 100000}),
        today: today,
      );

      expect(result.map((f) => f.currency), ['BRL', 'USD']);
      expect(result.first.startCents, 100000);
      expect(result.last.startCents, 20000);
    });

    test('a pending expense takes money out and a pending income puts it in', () {
      final result = buildForecasts(
        ForecastInputs(
          startingBalances: const {'BRL': 100000},
          pending: [
            PendingFlow(
              id: 'p1',
              description: 'Luz',
              amountCents: 20000,
              currency: 'BRL',
              isIncome: false,
              date: DateTime(2026, 10, 10),
            ),
            PendingFlow(
              id: 'p2',
              description: 'Venda',
              amountCents: 50000,
              currency: 'BRL',
              isIncome: true,
              date: DateTime(2026, 10, 12),
            ),
          ],
        ),
        today: today,
        days: 10,
      );

      expect(result.single.endCents, 130000);
      expect(result.single.events.map((e) => e.item.amountCents), [-20000, 50000]);
    });

    test('an unpaid invoice takes its total out on the due day', () {
      final result = buildForecasts(
        ForecastInputs(
          startingBalances: const {'BRL': 100000},
          invoices: [
            InvoiceDue(
              id: 'i1',
              cardName: 'Nubank',
              totalCents: 80000,
              currency: 'BRL',
              dueDate: DateTime(2026, 10, 17),
            ),
          ],
        ),
        today: today,
        days: 30,
      );

      final event = result.single.events.single;
      expect(event.item.kind, ForecastKind.invoice);
      expect(event.item.label, 'Nubank');
      expect(event.item.amountCents, -80000);
      expect(event.balanceAfterCents, 20000);
    });

    test('an invoice with nothing to pay is skipped', () {
      final result = buildForecasts(
        ForecastInputs(
          startingBalances: const {'BRL': 1000},
          invoices: [
            InvoiceDue(
              id: 'i1',
              cardName: 'Nubank',
              totalCents: 0,
              currency: 'BRL',
              dueDate: DateTime(2026, 10, 17),
            ),
          ],
        ),
        today: today,
      );

      expect(result.single.events, isEmpty);
    });

    test('a recurring item adds its next occurrences', () {
      final result = buildForecasts(
        ForecastInputs(
          startingBalances: const {'BRL': 500000},
          recurring: [template()],
        ),
        today: today,
      );

      final events = result.single.events;
      expect(events.map((e) => e.item.date), [DateTime(2026, 11, 5), DateTime(2026, 12, 5)]);
      expect(events.every((e) => e.item.kind == ForecastKind.recurring), isTrue);
      expect(result.single.endCents, 500000 - 2 * 150000);
    });

    test('a recurring income adds money', () {
      final result = buildForecasts(
        ForecastInputs(
          startingBalances: const {'BRL': 0},
          recurring: [template(income: true, cents: 400000, description: 'Salário')],
        ),
        today: today,
      );

      expect(result.single.endCents, 800000);
    });

    test('keeps each currency apart', () {
      final result = buildForecasts(
        ForecastInputs(
          startingBalances: const {'BRL': 1000},
          pending: [
            PendingFlow(
              id: 'p1',
              description: 'Hosting',
              amountCents: 2500,
              currency: 'USD',
              isIncome: false,
              date: DateTime(2026, 10, 10),
            ),
          ],
        ),
        today: today,
      );

      final usd = result.firstWhere((f) => f.currency == 'USD');
      final brl = result.firstWhere((f) => f.currency == 'BRL');
      expect(usd.startCents, 0);
      expect(usd.endCents, -2500);
      expect(brl.endCents, 1000);
    });

    test('looks 90 days ahead by default', () {
      final result = buildForecasts(
        const ForecastInputs(startingBalances: {'BRL': 1}),
        today: today,
      );

      expect(result.single.days, forecastMaxDays);
      expect(result.single.points.last.date, DateTime(2027, 1, 4));
    });
  });

  group('ForecastFrequency', () {
    test('reads the labels of the database', () {
      expect(ForecastFrequency.fromDb('daily'), ForecastFrequency.daily);
      expect(ForecastFrequency.fromDb('weekly'), ForecastFrequency.weekly);
      expect(ForecastFrequency.fromDb('monthly'), ForecastFrequency.monthly);
      expect(ForecastFrequency.fromDb('yearly'), ForecastFrequency.yearly);
    });

    test('refuses a label it does not know', () {
      expect(() => ForecastFrequency.fromDb('fortnightly'), throwsArgumentError);
    });
  });
}
