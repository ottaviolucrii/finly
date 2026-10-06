import 'package:finly/features/dashboard/domain/entities/dashboard_charts.dart';
import 'package:finly/features/dashboard/presentation/widgets/dashboard_charts_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  final points = [
    for (var month = 5; month <= 10; month++)
      MonthlyFlowPoint(
        month: DateTime(2026, month),
        incomeCents: month * 10000,
        expenseCents: month * 5000,
      ),
  ];

  testWidgets('the bar chart starts on the current month', (tester) async {
    await tester.pumpWidget(host(MonthlyBarChart(points: points, currency: 'BRL')));

    expect(find.text('out 2026'), findsOneWidget);
    expect(find.text('Entradas '), findsOneWidget);
    expect(find.text('Saídas '), findsOneWidget);
  });

  testWidgets('tapping a month shows its values', (tester) async {
    await tester.pumpWidget(host(MonthlyBarChart(points: points, currency: 'BRL')));

    final topLeft = tester.getTopLeft(find.byKey(const Key('monthly-bars')));
    await tester.tapAt(topLeft + const Offset(10, 40));
    await tester.pump();

    expect(find.text('mai 2026'), findsOneWidget);
    expect(find.text('out 2026'), findsNothing);
  });

  testWidgets('the donut legend gives each category its share', (tester) async {
    await tester.pumpWidget(
      host(
        const CategoryDonutChart(
          currency: 'BRL',
          slices: [
            CategorySlice(name: 'Alimentação', colorHex: '#F29D38', spentCents: 7500),
            CategorySlice(name: 'Transporte', colorHex: '#1060E3', spentCents: 2500),
          ],
        ),
      ),
    );

    expect(find.text('Alimentação'), findsOneWidget);
    expect(find.text('Transporte'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
  });
}