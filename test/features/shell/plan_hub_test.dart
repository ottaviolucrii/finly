import 'package:finly/core/error/failure.dart';
import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/budgets/domain/entities/budget_overview.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/budgets/presentation/cubit/budgets_state.dart';
import 'package:finly/features/forecast/presentation/cubit/forecast_state.dart';
import 'package:finly/features/goals/presentation/cubit/goals_state.dart';
import 'package:finly/features/shell/presentation/plan_hub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'plan_test_data.dart';

void main() {
  final today = DateTime(2026, 10, 11);
  late List<PlanDestination> opened;

  setUp(() => opened = []);

  ForecastState forecastLoaded() => ForecastState(
        status: ForecastStatus.loaded,
        forecasts: [forecastOf(today, [for (var i = 0; i < 31; i++) 987010])],
        today: today,
      );

  BudgetsState budgetsWith(List<BudgetProgress> items) => BudgetsState(
        status: BudgetsStatus.loaded,
        month: DateTime(2026, 10),
        overview: BudgetOverview(
          month: DateTime(2026, 10),
          items: items,
          expenseCategories: const [],
          withoutBudget: const [],
        ),
      );

  Future<void> show(
    WidgetTester tester, {
    bool business = false,
    ForecastState? forecast,
    BudgetsState? budgets,
    GoalsState? goals,
  }) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: PlanHub(
            isBusiness: business,
            onOpen: opened.add,
            forecast: forecast ?? forecastLoaded(),
            budgets: budgets ?? budgetsWith([budgetOf('Mercado', 108000, 150000)]),
            goals: goals ?? GoalsState(status: GoalsStatus.loaded, items: [goalOf('Reserva'), goalOf('Viagem', balance: 120000, target: 600000)]),
            clock: () => today,
          ),
        ),
      ),
    );
  }

  group('tabKickerFor', () {
    test('writes the month in full', () {
      expect(tabKickerFor(DateTime(2026, 10, 10)), 'Outubro de 2026');
      expect(tabKickerFor(DateTime(2027, 3, 1)), 'Março de 2027');
      expect(tabKickerFor(DateTime(2026, 1, 31)), 'Janeiro de 2026');
      expect(tabKickerFor(DateTime(2026, 12, 1)), 'Dezembro de 2026');
    });
  });

  testWidgets('shows the month, the forecast, the budgets, the goals and the tools', (tester) async {
    await show(tester);

    expect(find.text('OUTUBRO DE 2026'), findsOneWidget);
    expect(find.text('Planejar'), findsOneWidget);
    expect(find.text('Previsão'), findsOneWidget);
    expect(find.text('Orçamentos de outubro'), findsOneWidget);
    expect(find.text('METAS'), findsOneWidget);
    expect(find.text('Reserva'), findsOneWidget);
    expect(find.text('Viagem'), findsOneWidget);
    expect(find.text('Recorrências'), findsOneWidget);
    expect(find.text('Simulador de rendimento'), findsOneWidget);
  });

  testWidgets('the tax reserve is only for a company', (tester) async {
    await show(tester);
    expect(find.text('Reserva de impostos'), findsNothing);

    await show(tester, business: true);
    expect(find.text('Reserva de impostos'), findsOneWidget);
  });

  testWidgets('each link opens its place', (tester) async {
    await show(tester, business: true);

    await tester.tap(find.text('Ver completa'));
    await tester.tap(find.text('Ver todos'));
    await tester.tap(find.text('Ver todas'));
    await tester.tap(find.text('Reserva'));
    await tester.tap(find.text('Recorrências'));
    await tester.tap(find.text('Simulador de rendimento'));
    await tester.tap(find.text('Reserva de impostos'));

    expect(opened, [
      PlanDestination.forecast,
      PlanDestination.budgets,
      PlanDestination.goals,
      PlanDestination.goals,
      PlanDestination.recurring,
      PlanDestination.simulator,
      PlanDestination.taxReserve,
    ]);
  });

  testWidgets('shows at most four goals', (tester) async {
    await show(
      tester,
      goals: GoalsState(status: GoalsStatus.loaded, items: [for (var i = 1; i <= 6; i++) goalOf('Meta $i')]),
    );

    expect(find.text('Meta 4'), findsOneWidget);
    expect(find.text('Meta 5'), findsNothing);
  });

  testWidgets('with no goals, explains them and offers a new one', (tester) async {
    await show(tester, goals: const GoalsState(status: GoalsStatus.loaded));

    expect(find.textContaining('Junte dinheiro para algo'), findsOneWidget);
    await tester.tap(find.text('Nova meta'));
    expect(opened, [PlanDestination.goals]);
  });

  testWidgets('a forecast that failed says so, the rest still shows', (tester) async {
    await show(tester, forecast: const ForecastState(status: ForecastStatus.failure, failure: NetworkFailure('network_error')));

    expect(find.text('Não foi possível calcular a previsão agora.'), findsOneWidget);
    expect(find.text('Orçamentos de outubro'), findsOneWidget);
  });

  testWidgets('while the goals load, a spinner in their place', (tester) async {
    await show(tester, goals: const GoalsState());

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Nova meta'), findsOneWidget);
  });
}
