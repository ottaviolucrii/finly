import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/shell/presentation/plan_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'plan_test_data.dart';

void main() {
  final today = DateTime(2026, 10, 11);

  Future<void> show(WidgetTester tester, Widget child, {ThemeData? theme}) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Scaffold(body: ListView(padding: const EdgeInsets.all(20), children: [child])),
      ),
    );
  }

  group('endOfMonthBalance', () {
    test('is the balance on the last day of the month', () {
      // 11/10 to 09/11: the 31st of October is index 20.
      final balances = [for (var i = 0; i < 30; i++) 1000 + i];
      expect(endOfMonthBalance(forecastOf(today, balances), today), 1020);
    });

    test('is the last balance when the forecast ends before the end of the month', () {
      expect(endOfMonthBalance(forecastOf(today, [500, 400, 300]), today), 300);
    });

    test('on the last day of the month it is today', () {
      final last = DateTime(2026, 10, 31);
      expect(endOfMonthBalance(forecastOf(last, [700, 100]), last), 700);
    });
  });

  group('budgetTotals and closestToLimit', () {
    test('adds the budgets of the first currency and counts the ones passed', () {
      final totals = budgetTotals([
        budgetOf('Mercado', 108000, 150000),
        budgetOf('Lazer', 41200, 40000),
        budgetOf('Viagem', 50000, 10000, currency: 'USD'),
      ]);

      expect(totals.currency, 'BRL');
      expect(totals.spentCents, 149200);
      expect(totals.limitCents, 190000);
      expect(totals.overCount, 1);
    });

    test('no budgets, nothing', () {
      final totals = budgetTotals(const []);
      expect(totals.spentCents, 0);
      expect(totals.limitCents, 0);
    });

    test('the closest to the limit come first, three of them', () {
      final list = closestToLimit([
        budgetOf('A', 10, 100),
        budgetOf('B', 90, 100),
        budgetOf('C', 120, 100),
        budgetOf('D', 50, 100),
      ]);

      expect(list.map((b) => b.category.name), ['C', 'B', 'D']);
    });
  });

  group('PlanForecastCard', () {
    testWidgets('shows the end of the month and the lowest day', (tester) async {
      final balances = [for (var i = 0; i < 31; i++) i == 6 ? 740200 : 987010];
      await show(tester, PlanForecastCard(forecast: forecastOf(today, balances), today: today, onOpen: () {}));

      expect(find.text('Previsão'), findsOneWidget);
      expect(find.text('Fim do mês'), findsOneWidget);
      expect(find.text('R\$ 9.870,10'), findsOneWidget);
      expect(find.text('Menor saldo: R\$ 7.402,00 em 17/10/2026'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('warns in red when the balance goes below zero', (tester) async {
      final balances = [for (var i = 0; i < 31; i++) i < 4 ? 10000 : -5000];
      await show(tester, PlanForecastCard(forecast: forecastOf(today, balances), today: today, onOpen: () {}));

      final warning = tester.widget<Text>(find.text('Fica negativo em 15/10/2026'));
      expect(warning.style?.color, AppTheme.light.colorScheme.error);
    });

    testWidgets('shows a spinner while it loads, and a message when it fails', (tester) async {
      await show(tester, PlanForecastCard(forecast: null, today: today, onOpen: () {}));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await show(tester, PlanForecastCard(forecast: null, today: today, failed: true, onOpen: () {}));
      expect(find.text('Não foi possível calcular a previsão agora.'), findsOneWidget);
    });

    testWidgets('the link opens the full forecast', (tester) async {
      var opened = 0;
      await show(tester, PlanForecastCard(forecast: forecastOf(today, [100, 200]), today: today, onOpen: () => opened++));

      await tester.tap(find.text('Ver completa'));

      expect(opened, 1);
    });
  });

  group('PlanBudgetsCard', () {
    testWidgets('shows the ring, the totals and the closest categories', (tester) async {
      await show(
        tester,
        PlanBudgetsCard(
          items: [budgetOf('Mercado', 108000, 150000), budgetOf('Transporte', 27000, 60000), budgetOf('Lazer', 41200, 40000)],
          month: DateTime(2026, 10),
          today: today,
          onOpen: () {},
        ),
      );

      expect(find.text('Orçamentos de outubro'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);
      expect(find.text('R\$ 1.762,00 de R\$ 2.500,00'), findsOneWidget);
      expect(find.text('Faltam 20 dias · 1 categoria passou'), findsOneWidget);
      expect(find.text('R\$ 412,00 de R\$ 400,00 · passou'), findsOneWidget);
    });

    testWidgets('with no budgets, offers to create one', (tester) async {
      var opened = 0;
      await show(tester, PlanBudgetsCard(items: const [], month: DateTime(2026, 10), today: today, onOpen: () => opened++));

      await tester.tap(find.text('Criar orçamento'));

      expect(opened, 1);
    });

    testWidgets('on the last day of the month says so', (tester) async {
      await show(
        tester,
        PlanBudgetsCard(items: [budgetOf('Mercado', 100, 1000)], month: DateTime(2026, 10), today: DateTime(2026, 10, 31), onOpen: () {}),
      );

      expect(find.text('Último dia do mês'), findsOneWidget);
    });

    testWidgets('shows a spinner while it loads', (tester) async {
      await show(tester, PlanBudgetsCard(items: null, month: DateTime(2026, 10), today: today, onOpen: () {}));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('PlanGoalTile', () {
    testWidgets('shows the share, the name and the amounts', (tester) async {
      await show(tester, PlanGoalTile(goal: goalOf('Reserva'), onTap: () {}));

      expect(find.text('64%'), findsOneWidget);
      expect(find.text('Reserva'), findsOneWidget);
      expect(find.text('R\$ 9.600,00 de R\$ 15.000,00'), findsOneWidget);
    });

    testWidgets('a goal reached says so', (tester) async {
      await show(tester, PlanGoalTile(goal: goalOf('Celular', balance: 300000, target: 200000), onTap: () {}));

      expect(find.text('Meta alcançada'), findsOneWidget);
    });

    testWidgets('works in the dark theme', (tester) async {
      await show(tester, PlanGoalTile(goal: goalOf('Reserva'), onTap: () {}), theme: AppTheme.dark);

      expect(find.text('64%'), findsOneWidget);
    });
  });
}
