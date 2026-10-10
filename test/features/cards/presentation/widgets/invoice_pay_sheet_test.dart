import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_status.dart';
import 'package:finly/features/cards/presentation/widgets/invoice_pay_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const checking = AccountEntity(
    id: 'a2',
    workspaceId: 'w1',
    name: 'Conta corrente',
    type: AccountType.checking,
    currency: 'BRL',
    openingBalanceCents: 500000,
    postedBalanceCents: 500000,
    projectedBalanceCents: 500000,
  );
  const savings = AccountEntity(
    id: 'a3',
    workspaceId: 'w1',
    name: 'Poupança',
    type: AccountType.savings,
    currency: 'BRL',
    openingBalanceCents: 100000,
    postedBalanceCents: 100000,
    projectedBalanceCents: 100000,
  );

  InvoiceEntity invoice({int paid = 0}) {
    return InvoiceEntity(
      id: 'i1',
      accountId: 'card1',
      referenceMonth: DateTime(2026, 3),
      periodStart: DateTime(2026, 2, 11),
      periodEnd: DateTime(2026, 3, 10),
      dueDate: DateTime(2026, 3, 17),
      status: InvoiceStatus.closed,
      totalCents: 43335,
      paidCents: paid,
    );
  }

  String? confirmedAccount;
  int? confirmedAmount;
  var confirmed = 0;

  setUp(() {
    confirmedAccount = null;
    confirmedAmount = null;
    confirmed = 0;
  });

  /// The sheet opened the way the invoice screen opens it.
  Future<void> open(
    WidgetTester tester, {
    InvoiceEntity? forInvoice,
    List<AccountEntity> sources = const [checking, savings],
  }) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => InvoicePaySheet(
                    invoice: forInvoice ?? invoice(),
                    currency: 'BRL',
                    sources: sources,
                    onConfirm: (accountId, amount) {
                      confirmed++;
                      confirmedAccount = accountId;
                      confirmedAmount = amount;
                    },
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  bool payEnabled(WidgetTester tester) {
    return tester.widget<FilledButton>(find.byType(FilledButton)).onPressed != null;
  }

  String fieldText(WidgetTester tester) {
    return tester.widget<TextField>(find.byType(TextField)).controller!.text;
  }

  testWidgets('starts with everything that is still owed in the amount field', (tester) async {
    await open(tester);

    expect(fieldText(tester), '433,35');
    expect(find.text('Falta R\$ 433,35'), findsOneWidget);
  });

  testWidgets('says what was already paid when there was a payment', (tester) async {
    await open(tester, forInvoice: invoice(paid: 10000));

    expect(fieldText(tester), '333,35');
    expect(find.text('Já pago R\$ 100,00 de R\$ 433,35'), findsOneWidget);
    expect(find.text('Falta R\$ 333,35'), findsOneWidget);
  });

  testWidgets('does not talk about payments when there was none', (tester) async {
    await open(tester);

    expect(find.textContaining('Já pago'), findsNothing);
  });

  testWidgets('the button waits for an account', (tester) async {
    await open(tester);

    expect(payEnabled(tester), isFalse);

    await tester.tap(find.textContaining('Conta corrente'));
    await tester.pump();

    expect(payEnabled(tester), isTrue);
  });

  testWidgets('paying everything sends no amount, so the invoice is settled', (tester) async {
    await open(tester);

    await tester.tap(find.textContaining('Conta corrente'));
    await tester.pump();
    expect(find.text('Quita a fatura.'), findsOneWidget);
    expect(find.text('Pagar R\$ 433,35'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(confirmed, 1);
    expect(confirmedAccount, 'a2');
    expect(confirmedAmount, isNull);
    expect(find.byType(InvoicePaySheet), findsNothing);
  });

  testWidgets('paying a part sends the amount', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.textContaining('Poupança'));
    await tester.pump();

    expect(find.text('Pagar R\$ 100,00'), findsOneWidget);
    expect(find.text('Depois deste pagamento falta R\$ 333,35.'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(confirmedAccount, 'a3');
    expect(confirmedAmount, 10000);
  });

  testWidgets('a part of an invoice that was already partly paid', (tester) async {
    await open(tester, forInvoice: invoice(paid: 10000));

    await tester.enterText(find.byType(TextField), '50,50');
    await tester.tap(find.textContaining('Conta corrente'));
    await tester.pump();

    expect(find.text('Depois deste pagamento falta R\$ 282,85.'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(confirmedAmount, 5050);
  });

  testWidgets('an amount above what is owed is refused, with the reason', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), '500');
    await tester.tap(find.textContaining('Conta corrente'));
    await tester.pump();

    expect(find.text('O valor é maior do que falta pagar (R\$ 433,35).'), findsOneWidget);
    expect(payEnabled(tester), isFalse);
  });

  testWidgets('zero is refused, with the reason', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.textContaining('Conta corrente'));
    await tester.pump();

    expect(find.text('Informe um valor maior que zero.'), findsOneWidget);
    expect(payEnabled(tester), isFalse);
  });

  testWidgets('something that is not an amount is refused, with the reason', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.tap(find.textContaining('Conta corrente'));
    await tester.pump();

    expect(find.text('Valor inválido. Use o formato 1.234,56.'), findsOneWidget);
    expect(payEnabled(tester), isFalse);
  });

  testWidgets('an empty field says nothing, and the button waits', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.textContaining('Conta corrente'));
    await tester.pump();

    expect(find.textContaining('Informe'), findsNothing);
    expect(find.textContaining('inválido'), findsNothing);
    expect(payEnabled(tester), isFalse);
    expect(find.text('Pagar'), findsOneWidget);
  });

  testWidgets('"Pagar tudo" puts everything that is owed back in the field', (tester) async {
    await open(tester, forInvoice: invoice(paid: 10000));

    await tester.enterText(find.byType(TextField), '10');
    await tester.pump();
    expect(fieldText(tester), '10');

    await tester.tap(find.text('Pagar tudo'));
    await tester.pump();

    expect(fieldText(tester), '333,35');
    expect(find.text('Quita a fatura.'), findsOneWidget);
  });

  testWidgets('cancelling closes the sheet and pays nothing', (tester) async {
    await open(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(confirmed, 0);
    expect(find.byType(InvoicePaySheet), findsNothing);
  });

  testWidgets('without an account that can pay, it says so', (tester) async {
    await open(tester, sources: const []);

    expect(find.textContaining('Você precisa de uma conta em BRL'), findsOneWidget);
    expect(payEnabled(tester), isFalse);
  });

  testWidgets('the accounts show their balance', (tester) async {
    await open(tester);

    expect(find.text('Conta corrente · R\$ 5.000,00'), findsOneWidget);
    expect(find.text('Poupança · R\$ 1.000,00'), findsOneWidget);
  });
}
