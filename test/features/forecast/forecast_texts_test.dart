import 'package:finly/features/forecast/domain/entities/forecast_items.dart';
import 'package:finly/features/forecast/forecast_texts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 6);

  ForecastItem item(ForecastKind kind, String label) {
    return ForecastItem(
      kind: kind,
      label: label,
      amountCents: -1000,
      currency: 'BRL',
      date: today,
    );
  }

  Forecast forecastWith(List<int> balances) {
    return Forecast(
      currency: 'BRL',
      startCents: balances.first,
      points: [
        for (var i = 0; i < balances.length; i++)
          ForecastPoint(
            date: DateTime(today.year, today.month, today.day + i),
            balanceCents: balances[i],
          ),
      ],
      events: const [],
    );
  }

  group('forecastEventTitle', () {
    test('a bill and a recurring item show their description', () {
      expect(forecastEventTitle(item(ForecastKind.pending, 'Luz')), 'Luz');
      expect(forecastEventTitle(item(ForecastKind.recurring, 'Aluguel')), 'Aluguel');
    });

    test('an invoice shows the name of the card', () {
      expect(forecastEventTitle(item(ForecastKind.invoice, 'Nubank')), 'Fatura Nubank');
    });
  });

  group('forecastKindLabel', () {
    test('names every kind', () {
      expect(forecastKindLabel(ForecastKind.pending), 'Lançamento pendente');
      expect(forecastKindLabel(ForecastKind.recurring), 'Recorrente');
      expect(forecastKindLabel(ForecastKind.invoice), 'Fatura do cartão');
    });
  });

  test('forecastHorizonLabel says how many days', () {
    expect(forecastHorizonLabel(30), 'Em 30 dias');
    expect(forecastHorizonLabel(90), 'Em 90 dias');
  });

  group('forecastWarning', () {
    test('is null when the balance never goes below zero', () {
      expect(forecastWarning(forecastWith([100, 50, 0, 10]), today), isNull);
    });

    test('says today when it is already negative', () {
      expect(
        forecastWarning(forecastWith([-5, -10]), today),
        'O saldo pode ficar negativo hoje.',
      );
    });

    test('says tomorrow, with the date', () {
      expect(
        forecastWarning(forecastWith([100, -50, -80]), today),
        'O saldo pode ficar negativo amanhã (07/10/2026).',
      );
    });

    test('says in how many days, with the date', () {
      expect(
        forecastWarning(forecastWith([100, 90, 80, 70, 60, -1]), today),
        'O saldo pode ficar negativo em 5 dias (11/10/2026).',
      );
    });
  });

  test('the explanation has a few short lines', () {
    expect(forecastExplanation.length, inInclusiveRange(4, 8));
    expect(forecastExplanation.every((line) => line.isNotEmpty), isTrue);
  });
}
