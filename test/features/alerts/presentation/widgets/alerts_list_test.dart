import 'package:finly/features/alerts/domain/entities/app_alert.dart';
import 'package:finly/features/alerts/presentation/widgets/dashboard_alerts_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppAlert bill(String subject, int days) {
    return AppAlert(
      kind: AlertKind.billDueSoon,
      subject: subject,
      currency: 'BRL',
      amountCents: 10000,
      dueDate: DateTime(2026, 10, 6 + days),
      daysUntilDue: days,
    );
  }

  const budget = AppAlert(
    kind: AlertKind.budgetOver,
    subject: 'Alimentação',
    currency: 'BRL',
    amountCents: 120000,
    limitCents: 100000,
    percent: 120,
  );

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

  testWidgets('shows the alerts under a heading', (tester) async {
    await tester.pumpWidget(
      host(
        AlertsList(
          alerts: [budget, bill('Internet', 2)],
          onOpenBudgets: () {},
          onOpenTransactions: () {},
        ),
      ),
    );

    expect(find.text('Atenção'), findsOneWidget);
    expect(find.text('Orçamento de Alimentação estourado'), findsOneWidget);
    expect(find.text('Vence em 2 dias: Internet'), findsOneWidget);
  });

  testWidgets('shows only five and says how many more there are', (tester) async {
    await tester.pumpWidget(
      host(
        AlertsList(
          alerts: [for (var i = 0; i < 7; i++) bill('Conta $i', 2)],
          onOpenBudgets: () {},
          onOpenTransactions: () {},
        ),
      ),
    );

    expect(find.textContaining('Vence em 2 dias'), findsNWidgets(5));
    expect(find.text('+ 2 alertas'), findsOneWidget);
  });

  testWidgets('says "1 alerta" in the singular', (tester) async {
    await tester.pumpWidget(
      host(
        AlertsList(
          alerts: [for (var i = 0; i < 6; i++) bill('Conta $i', 2)],
          onOpenBudgets: () {},
          onOpenTransactions: () {},
        ),
      ),
    );

    expect(find.text('+ 1 alerta'), findsOneWidget);
  });

  testWidgets('a budget alert opens the budgets, a bill opens the transactions', (tester) async {
    var budgets = 0;
    var transactions = 0;

    await tester.pumpWidget(
      host(
        AlertsList(
          alerts: [budget, bill('Internet', 2)],
          onOpenBudgets: () => budgets++,
          onOpenTransactions: () => transactions++,
        ),
      ),
    );

    await tester.tap(find.text('Orçamento de Alimentação estourado'));
    await tester.pump();
    expect(budgets, 1);
    expect(transactions, 0);

    await tester.tap(find.text('Vence em 2 dias: Internet'));
    await tester.pump();
    expect(budgets, 1);
    expect(transactions, 1);
  });
}