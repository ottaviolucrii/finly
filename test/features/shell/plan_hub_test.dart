import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/shell/presentation/plan_hub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<PlanDestination> opened;

  setUp(() => opened = []);

  Future<void> show(WidgetTester tester, {bool business = false}) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: PlanHub(
            isBusiness: business,
            onOpen: opened.add,
            clock: () => DateTime(2026, 10, 10),
          ),
        ),
      ),
    );
  }

  group('tabKickerFor', () {
    test('writes the month in full', () {
      expect(tabKickerFor(DateTime(2026, 10, 10)), 'Outubro de 2026');
      expect(tabKickerFor(DateTime(2027, 3, 1)), 'Março de 2027');
    });

    test('works for the first and the last month', () {
      expect(tabKickerFor(DateTime(2026, 1, 31)), 'Janeiro de 2026');
      expect(tabKickerFor(DateTime(2026, 12, 1)), 'Dezembro de 2026');
    });
  });

  testWidgets('shows the month and the title', (tester) async {
    await show(tester);

    expect(find.text('OUTUBRO DE 2026'), findsOneWidget);
    expect(find.text('Planejar'), findsOneWidget);
  });

  testWidgets('lists what can be planned', (tester) async {
    await show(tester);

    for (final title in ['Orçamentos', 'Metas', 'Previsão de saldo', 'Recorrências', 'Simulador de rendimento']) {
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('the tax reserve is only for a company', (tester) async {
    await show(tester);
    expect(find.text('Reserva de impostos'), findsNothing);

    await show(tester, business: true);
    expect(find.text('Reserva de impostos'), findsOneWidget);
  });

  testWidgets('each row opens its place', (tester) async {
    await show(tester, business: true);

    await tester.tap(find.text('Orçamentos'));
    await tester.tap(find.text('Metas'));
    await tester.tap(find.text('Previsão de saldo'));
    await tester.tap(find.text('Recorrências'));
    await tester.tap(find.text('Simulador de rendimento'));
    await tester.tap(find.text('Reserva de impostos'));

    expect(opened, [
      PlanDestination.budgets,
      PlanDestination.goals,
      PlanDestination.forecast,
      PlanDestination.recurring,
      PlanDestination.simulator,
      PlanDestination.taxReserve,
    ]);
  });
}
