import 'package:equatable/equatable.dart';

/// Where a future money movement comes from.
enum ForecastKind { pending, recurring, invoice }

/// The same four frequencies the database has for recurring items.
enum ForecastFrequency {
  daily,
  weekly,
  monthly,
  yearly;

  /// Throws for an unknown value, so a new one in the database is noticed.
  static ForecastFrequency fromDb(String value) => values.byName(value);
}

/// A pending income or expense that is not a card purchase and not a
/// transfer (a card purchase is paid by the invoice).
class PendingFlow extends Equatable {
  final String id;
  final String description;

  /// Always positive; [isIncome] gives the direction.
  final int amountCents;
  final String currency;
  final bool isIncome;

  /// The day it is due (date only).
  final DateTime date;

  const PendingFlow({
    required this.id,
    required this.description,
    required this.amountCents,
    required this.currency,
    required this.isIncome,
    required this.date,
  });

  @override
  List<Object?> get props => [id, description, amountCents, currency, isIncome, date];
}

/// A recurring item that is still active. Its next occurrences have not been
/// generated yet beyond [generatedCount].
class RecurringTemplate extends Equatable {
  final String id;
  final String description;
  final int amountCents;
  final String currency;
  final bool isIncome;
  final ForecastFrequency frequency;
  final int intervalCount;
  final DateTime startDate;
  final DateTime? endDate;

  /// How many occurrences the database already generated (numbered from 0).
  final int generatedCount;

  /// The day the item was created: earlier occurrences are never generated.
  final DateTime createdOn;

  const RecurringTemplate({
    required this.id,
    required this.description,
    required this.amountCents,
    required this.currency,
    required this.isIncome,
    required this.frequency,
    required this.intervalCount,
    required this.startDate,
    required this.generatedCount,
    required this.createdOn,
    this.endDate,
  });

  @override
  List<Object?> get props => [
        id,
        description,
        amountCents,
        currency,
        isIncome,
        frequency,
        intervalCount,
        startDate,
        endDate,
        generatedCount,
        createdOn,
      ];
}

/// A credit card invoice that is not paid yet, due on [dueDate].
class InvoiceDue extends Equatable {
  final String id;
  final String cardName;
  final int totalCents;
  final String currency;
  final DateTime dueDate;

  const InvoiceDue({
    required this.id,
    required this.cardName,
    required this.totalCents,
    required this.currency,
    required this.dueDate,
  });

  @override
  List<Object?> get props => [id, cardName, totalCents, currency, dueDate];
}

/// Everything the forecast starts from.
class ForecastInputs extends Equatable {
  /// What the accounts hold today (confirmed only; credit cards and archived
  /// accounts left out), per currency.
  final Map<String, int> startingBalances;
  final List<PendingFlow> pending;
  final List<RecurringTemplate> recurring;
  final List<InvoiceDue> invoices;

  const ForecastInputs({
    this.startingBalances = const {},
    this.pending = const [],
    this.recurring = const [],
    this.invoices = const [],
  });

  @override
  List<Object?> get props => [startingBalances, pending, recurring, invoices];
}

/// One future money movement, with its direction in the sign of the amount.
class ForecastItem extends Equatable {
  final ForecastKind kind;

  /// The description of a bill, or the name of a card for an invoice.
  final String label;

  /// Negative when money goes out.
  final int amountCents;
  final String currency;
  final DateTime date;

  const ForecastItem({
    required this.kind,
    required this.label,
    required this.amountCents,
    required this.currency,
    required this.date,
  });

  ForecastItem movedTo(DateTime day) {
    return ForecastItem(
      kind: kind,
      label: label,
      amountCents: amountCents,
      currency: currency,
      date: day,
    );
  }

  @override
  List<Object?> get props => [kind, label, amountCents, currency, date];
}

/// The balance at the end of one day.
class ForecastPoint extends Equatable {
  final DateTime date;
  final int balanceCents;

  const ForecastPoint({required this.date, required this.balanceCents});

  @override
  List<Object?> get props => [date, balanceCents];
}

/// A movement and the balance right after it.
class ForecastEvent extends Equatable {
  final ForecastItem item;
  final int balanceAfterCents;

  const ForecastEvent({required this.item, required this.balanceAfterCents});

  @override
  List<Object?> get props => [item, balanceAfterCents];
}

/// The projected balance of one currency, day by day.
class Forecast extends Equatable {
  final String currency;

  /// What the accounts hold today, before any of the movements.
  final int startCents;

  /// One point per day, from today (index 0) to the last day.
  final List<ForecastPoint> points;

  /// The movements in the period, in order.
  final List<ForecastEvent> events;

  const Forecast({
    required this.currency,
    required this.startCents,
    required this.points,
    required this.events,
  });

  /// How many days after today the forecast reaches.
  int get days => points.length - 1;

  int get endCents => points.last.balanceCents;

  /// The first day with the lowest balance.
  ForecastPoint get lowest {
    var best = points.first;
    for (final point in points) {
      if (point.balanceCents < best.balanceCents) best = point;
    }
    return best;
  }

  /// The first day the balance is below zero, if it ever is.
  DateTime? get firstNegativeDate {
    for (final point in points) {
      if (point.balanceCents < 0) return point.date;
    }
    return null;
  }

  /// The same forecast cut to the first [days] days.
  Forecast limitTo(int days) {
    final keep = days.clamp(0, this.days);
    final last = points[keep].date;

    return Forecast(
      currency: currency,
      startCents: startCents,
      points: points.sublist(0, keep + 1),
      events: [
        for (final event in events)
          if (!event.item.date.isAfter(last)) event,
      ],
    );
  }

  @override
  List<Object?> get props => [currency, startCents, points, events];
}
