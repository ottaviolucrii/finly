import 'package:finly/features/forecast/domain/entities/forecast_items.dart';
import 'package:finly/features/forecast/presentation/widgets/forecast_line_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<ForecastPoint> series(List<int> balances) {
    return [
      for (var i = 0; i < balances.length; i++)
        ForecastPoint(date: DateTime(2026, 10, 6 + i), balanceCents: balances[i]),
    ];
  }

  Future<void> show(WidgetTester tester, List<ForecastPoint> points) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ForecastLineChart(points: points, currency: 'BRL'),
          ),
        ),
      ),
    );
  }

  group('compactAmount', () {
    test('small amounts are whole reais', () {
      expect(compactAmount(85000), '850');
      expect(compactAmount(0), '0');
      expect(compactAmount(99900), '999');
    });

    test('thousands say "mil"', () {
      expect(compactAmount(123400), '1,2 mil');
      expect(compactAmount(1250000), '12,5 mil');
      expect(compactAmount(100000), '1,0 mil');
    });

    test('millions say "mi"', () {
      expect(compactAmount(150000000), '1,5 mi');
    });

    test('keeps the minus sign', () {
      expect(compactAmount(-85000), '-850');
      expect(compactAmount(-123400), '-1,2 mil');
      expect(compactAmount(-150000000), '-1,5 mi');
    });
  });

  test('shortDate is day and month', () {
    expect(shortDate(DateTime(2026, 10, 5)), '05/10');
    expect(shortDate(DateTime(2026, 12, 31)), '31/12');
  });

  group('ForecastChartScale', () {
    test('leaves 10% of room above and below the data', () {
      final scale = ForecastChartScale.of(series([100000, 300000]));

      expect(scale.minCents, 80000);
      expect(scale.maxCents, 320000);
    });

    test('puts the lowest value near the bottom and the highest near the top', () {
      final scale = ForecastChartScale.of(series([100000, 300000]));

      expect(scale.yFraction(80000), 0);
      expect(scale.yFraction(320000), 1);
      expect(scale.yFraction(100000), greaterThan(0));
      expect(scale.yFraction(300000), lessThan(1));
    });

    test('spreads the days from the left to the right', () {
      final scale = ForecastChartScale.of(series([1, 2, 3, 4, 5]));

      expect(scale.xFraction(0), 0);
      expect(scale.xFraction(2), 0.5);
      expect(scale.xFraction(4), 1);
    });

    test('a single point sits at the left', () {
      final scale = ForecastChartScale.of(series([500]));

      expect(scale.xFraction(0), 0);
    });

    test('a flat line still gets a range to be drawn in', () {
      final scale = ForecastChartScale.of(series([50000, 50000, 50000]));

      expect(scale.maxCents, greaterThan(scale.minCents));
      expect(scale.yFraction(50000), closeTo(0.5, 0.001));
    });

    test('a flat line at zero still gets a range', () {
      final scale = ForecastChartScale.of(series([0, 0]));

      expect(scale.maxCents, greaterThan(scale.minCents));
    });

    test('shows the line of zero only when the data goes through it', () {
      expect(ForecastChartScale.of(series([-100, 200])).showsZero, isTrue);
      expect(ForecastChartScale.of(series([100, 200])).showsZero, isFalse);
      expect(ForecastChartScale.of(series([-300, -200])).showsZero, isFalse);
    });
  });

  group('ForecastChartPainter', () {
    ForecastChartPainter painter({List<ForecastPoint>? points, Color line = Colors.blue}) {
      return ForecastChartPainter(
        points: points ?? series([1, 2]),
        lineColor: line,
        negativeColor: Colors.red,
        markerColor: Colors.amber,
        gridColor: Colors.grey,
        textStyle: const TextStyle(fontSize: 11),
      );
    }

    test('repaints when the colours change', () {
      final points = series([1, 2]);

      expect(painter(points: points).shouldRepaint(painter(points: points)), isFalse);
      expect(
        painter(points: points).shouldRepaint(painter(points: points, line: Colors.green)),
        isTrue,
      );
    });

    test('repaints when the points change', () {
      expect(painter().shouldRepaint(painter(points: series([3, 4]))), isTrue);
    });
  });

  group('ForecastLineChart', () {
    testWidgets('draws a balance that stays above zero', (tester) async {
      await show(tester, series([100000, 90000, 120000, 80000]));

      expect(tester.takeException(), isNull);
      expect(
        find.descendant(of: find.byType(ForecastLineChart), matching: find.byType(CustomPaint)),
        findsOneWidget,
      );
    });

    testWidgets('draws a balance that goes below zero', (tester) async {
      await show(tester, series([50000, 10000, -20000, -5000, 30000]));

      expect(tester.takeException(), isNull);
    });

    testWidgets('draws a flat line', (tester) async {
      await show(tester, series([70000, 70000, 70000]));

      expect(tester.takeException(), isNull);
    });

    testWidgets('draws a single point', (tester) async {
      await show(tester, series([70000]));

      expect(tester.takeException(), isNull);
    });

    testWidgets('draws ninety days', (tester) async {
      await show(tester, series([for (var i = 0; i <= 90; i++) 100000 - i * 1000]));

      expect(tester.takeException(), isNull);
    });

    testWidgets('has a description for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await show(tester, series([100000, 50000]));

      expect(find.bySemanticsLabel(RegExp('Gráfico da previsão de saldo')), findsOneWidget);
      handle.dispose();
    });
  });
}
