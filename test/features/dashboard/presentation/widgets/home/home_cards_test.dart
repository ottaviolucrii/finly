import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:finly/features/dashboard/presentation/widgets/home/home_cards.dart';
import 'package:finly/features/dashboard/presentation/widgets/home/home_view.dart';
import 'package:finly/features/goals/domain/entities/goal.dart';
import 'package:finly/features/goals/domain/entities/goal_progress.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 10, 9);

  Future<void> show(WidgetTester tester, Widget child, {ThemeData? theme}) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Scaffold(body: ListView(padding: const EdgeInsets.all(20), children: [child])),
      ),
    );
  }

  group('month names', () {
    test('in full for the title', () {
      expect(monthName(DateTime(2026, 10)), 'Outubro');
      expect(monthName(DateTime(2026, 1)), 'Janeiro');
      expect(monthName(DateTime(2026, 12)), 'Dezembro');
    });

    test('short and in capitals for a date', () {
      expect(monthShort(DateTime(2026, 10, 15)), 'OUT');
      expect(monthShort(DateTime(2026, 3, 1)), 'MAR');
    });
  });

  group('HomeMonthCard', () {
    const flow = CurrencyFlow(
      currency: 'BRL',
      incomePostedCents: 820000,
      incomePendingCents: 0,
      expensePostedCents: 573190,
      expensePendingCents: 0,
    );

    testWidgets('shows what came in, what went out and what was left', (tester) async {
      await show(tester, HomeMonthCard(month: DateTime(2026, 10), flow: flow, hidden: false, onOpenReport: () {}));

      expect(find.text('Outubro'), findsOneWidget);
      expect(find.text('R\$ 8.200,00'), findsOneWidget);
      expect(find.text('R\$ 5.731,90'), findsOneWidget);
      expect(find.text('Sobrou no mês'), findsOneWidget);
      expect(find.text('+ R\$ 2.468,10'), findsOneWidget);
      expect(find.text('Relatório'), findsOneWidget);
    });

    testWidgets('says the month was short when more went out', (tester) async {
      await show(
        tester,
        HomeMonthCard(
          month: DateTime(2026, 10),
          flow: const CurrencyFlow(currency: 'BRL', incomePostedCents: 100000, incomePendingCents: 0, expensePostedCents: 150000, expensePendingCents: 0),
          hidden: false,
        ),
      );

      expect(find.text('Faltou no mês'), findsOneWidget);
      expect(find.text('− R\$ 500,00'), findsOneWidget);
    });

    testWidgets('hides the amounts when asked', (tester) async {
      await show(tester, HomeMonthCard(month: DateTime(2026, 10), flow: flow, hidden: true));

      expect(find.text('R\$ 8.200,00'), findsNothing);
      expect(find.text('R\$ ••••••'), findsNWidgets(3));
    });

    testWidgets('says what is still expected', (tester) async {
      await show(
        tester,
        HomeMonthCard(
          month: DateTime(2026, 10),
          flow: const CurrencyFlow(currency: 'BRL', incomePostedCents: 0, incomePendingCents: 650000, expensePostedCents: 0, expensePendingCents: 180000),
          hidden: false,
        ),
      );

      expect(find.textContaining('Ainda previsto: + R\$ 6.500,00 entrando, − R\$ 1.800,00 saindo.'), findsOneWidget);
    });

    testWidgets('says when nothing happened yet', (tester) async {
      await show(tester, HomeMonthCard(month: DateTime(2026, 10), flow: null, hidden: false));

      expect(find.text('Nenhum lançamento neste mês ainda.'), findsOneWidget);
    });

    testWidgets('the report link opens the report', (tester) async {
      var opened = 0;
      await show(tester, HomeMonthCard(month: DateTime(2026, 10), flow: flow, hidden: false, onOpenReport: () => opened++));

      await tester.tap(find.text('Relatório'));

      expect(opened, 1);
    });
  });

  group('HomeCreditCardsCard', () {
    CreditCardEntity card(String name, {int used = 184335, int limit = 500000}) => CreditCardEntity(
          accountId: name,
          workspaceId: 'w1',
          name: name,
          currency: 'BRL',
          limitCents: limit,
          closingDay: 10,
          dueDay: 17,
          usedCents: used,
        );

    testWidgets('shows how much of the limit is in use', (tester) async {
      await show(tester, HomeCreditCardsCard(cards: [card('Nubank')], onOpen: () {}));

      expect(find.text('Cartão'), findsOneWidget);
      expect(find.text('Nubank'), findsOneWidget);
      expect(find.text('Fecha dia 10 · vence dia 17'), findsOneWidget);
      expect(find.text('R\$ 1.843,35'), findsOneWidget);
      expect(find.text('Livre R\$ 3.156,65 de R\$ 5.000,00'), findsOneWidget);
    });

    testWidgets('says when the limit was passed', (tester) async {
      await show(tester, HomeCreditCardsCard(cards: [card('Nubank', used: 520000)], onOpen: () {}));

      expect(find.text('Passou do limite de R\$ 5.000,00'), findsOneWidget);
    });

    testWidgets('shows two cards and counts the rest', (tester) async {
      await show(tester, HomeCreditCardsCard(cards: [card('Nubank'), card('Itaú'), card('Inter')], onOpen: () {}));

      expect(find.text('Cartões'), findsOneWidget);
      expect(find.text('Inter'), findsNothing);
      expect(find.text('+ 1 cartão'), findsOneWidget);
    });

    testWidgets('the link opens the invoices', (tester) async {
      var opened = 0;
      await show(tester, HomeCreditCardsCard(cards: [card('Nubank')], onOpen: () => opened++));

      await tester.tap(find.text('Ver faturas'));

      expect(opened, 1);
    });
  });

  group('HomeBudgetsCard', () {
    BudgetProgress budget(String name, int spent, int limit) => BudgetProgress(
          budget: BudgetEntity(id: name, workspaceId: 'w1', categoryId: name, effectiveFrom: DateTime(2026, 10), limitCents: limit, currency: 'BRL'),
          category: CategoryEntity(id: name, workspaceId: 'w1', name: name, kind: CategoryKind.expense, icon: 'category', colorHex: '#1060E3', isDefault: false),
          spentCents: spent,
        );

    testWidgets('shows what was spent of each budget', (tester) async {
      await show(tester, HomeBudgetsCard(budgets: [budget('Mercado', 108000, 150000)], onOpen: () {}));

      expect(find.text('Mercado'), findsOneWidget);
      expect(find.text('R\$ 1.080,00 de R\$ 1.500,00'), findsOneWidget);
    });

    testWidgets('says when a budget was passed, in red', (tester) async {
      await show(tester, HomeBudgetsCard(budgets: [budget('Lazer', 41200, 40000)], onOpen: () {}));

      final label = tester.widget<Text>(find.text('R\$ 412,00 de R\$ 400,00 · passou'));
      expect(label.style?.color, AppTheme.light.colorScheme.error);
    });

    testWidgets('the bar is gold near the limit and blue before it', (tester) async {
      await show(tester, HomeBudgetsCard(budgets: [budget('Mercado', 85000, 100000), budget('Transporte', 10000, 100000)], onOpen: () {}));

      final bars = tester.widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).toList();
      expect(bars[0].color, AppColors.gold);
      expect(bars[1].color, AppTheme.light.colorScheme.primary);
    });
  });

  group('HomeUpcomingCard', () {
    TransactionEntity item(String description, DateTime when, {TransactionType type = TransactionType.expense}) => TransactionEntity(
          id: description,
          workspaceId: 'w1',
          accountId: 'a1',
          categoryId: null,
          type: type,
          status: TransactionStatus.pending,
          amountCents: 180000,
          currency: 'BRL',
          description: description,
          occurredAt: when,
        );

    testWidgets('says when each item is due', (tester) async {
      await show(
        tester,
        HomeUpcomingCard(
          items: [
            item('Atrasada', DateTime(2026, 10, 8)),
            item('Hoje', DateTime(2026, 10, 10, 15)),
            item('Amanhã', DateTime(2026, 10, 11)),
            item('Aluguel', DateTime(2026, 10, 15)),
          ],
          now: now,
          onOpen: () {},
        ),
      );

      expect(find.textContaining('Atrasado · era 08/10/2026'), findsOneWidget);
      expect(find.text('Em 5 dias'), findsOneWidget);
      expect(find.text('OUT'), findsNWidgets(4));
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('a late item says so in red', (tester) async {
      await show(tester, HomeUpcomingCard(items: [item('Luz', DateTime(2026, 10, 8))], now: now, onOpen: () {}));

      final when = tester.widget<Text>(find.textContaining('Atrasado'));
      expect(when.style?.color, AppTheme.light.colorScheme.error);
    });

    testWidgets('money in has a plus sign and is green', (tester) async {
      await show(tester, HomeUpcomingCard(items: [item('Salário', DateTime(2026, 10, 20), type: TransactionType.income)], now: now, onOpen: () {}));

      final amount = tester.widget<Text>(find.text('+ R\$ 1.800,00'));
      expect(amount.style?.color, AppColors.positive);
    });

    testWidgets('shows five and counts the rest', (tester) async {
      await show(
        tester,
        HomeUpcomingCard(
          items: [for (var day = 11; day <= 17; day++) item('Conta $day', DateTime(2026, 10, day))],
          now: now,
          onOpen: () {},
        ),
      );

      expect(find.text('Conta 15'), findsOneWidget);
      expect(find.text('Conta 16'), findsNothing);
      expect(find.text('+ 2 mais'), findsOneWidget);
    });
  });

  group('HomeGoalCard and goalToShow', () {
    GoalProgress goal(String name, {int balance = 960000, int target = 1500000, DateTime? date}) => GoalProgress(
          goal: Goal(id: name, workspaceId: 'w1', accountId: 'a1', currency: 'BRL', name: name, targetCents: target, targetDate: date),
          accountName: 'Poupança',
          balanceCents: balance,
        );

    test('the first goal not reached yet is the one shown', () {
      final reached = goal('Celular', balance: 300000, target: 200000);
      final open = goal('Reserva');

      expect(goalToShow([reached, open]), open);
    });

    test('when all are reached, the first is shown', () {
      final reached = goal('Celular', balance: 300000, target: 200000);

      expect(goalToShow([reached]), reached);
    });

    test('no goals, nothing to show', () {
      expect(goalToShow(const []), isNull);
    });

    testWidgets('shows how far the goal is', (tester) async {
      await show(tester, HomeGoalCard(goal: goal('Reserva de emergência'), today: now, onOpen: () {}));

      expect(find.text('Reserva de emergência'), findsOneWidget);
      expect(find.text('64%'), findsOneWidget);
      expect(find.text('R\$ 9.600,00 de R\$ 15.000,00'), findsOneWidget);
    });

    testWidgets('says what to put aside each month when there is a date', (tester) async {
      await show(tester, HomeGoalCard(goal: goal('Reserva', date: DateTime(2027, 6, 10)), today: now, onOpen: () {}));

      expect(find.textContaining('por mês'), findsOneWidget);
    });

    testWidgets('says when it was reached', (tester) async {
      await show(tester, HomeGoalCard(goal: goal('Celular', balance: 300000, target: 200000), today: now, onOpen: () {}));

      expect(find.text('Meta alcançada'), findsOneWidget);
    });

    testWidgets('a tap opens the goals', (tester) async {
      var opened = 0;
      await show(tester, HomeGoalCard(goal: goal('Reserva'), today: now, onOpen: () => opened++));

      await tester.tap(find.text('Reserva'));

      expect(opened, 1);
    });
  });

  testWidgets('the cards work in the dark theme', (tester) async {
    await show(
      tester,
      HomeMonthCard(
        month: DateTime(2026, 10),
        flow: const CurrencyFlow(currency: 'BRL', incomePostedCents: 820000, incomePendingCents: 0, expensePostedCents: 573190, expensePendingCents: 0),
        hidden: false,
      ),
      theme: AppTheme.dark,
    );

    expect(find.text('+ R\$ 2.468,10'), findsOneWidget);
  });
}
