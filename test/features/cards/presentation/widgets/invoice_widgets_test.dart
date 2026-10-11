import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_status.dart';
import 'package:finly/features/cards/presentation/widgets/invoice_widgets.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 11);

  InvoiceEntity invoice({
    DateTime? month,
    InvoiceStatus status = InvoiceStatus.open,
    int total = 184335,
    int paid = 0,
  }) {
    final m = month ?? DateTime(2026, 11);
    return InvoiceEntity(
      id: 'i1',
      accountId: 'card',
      referenceMonth: m,
      periodStart: DateTime(m.year, m.month - 1, 11),
      periodEnd: DateTime(m.year, m.month, 10),
      dueDate: DateTime(m.year, m.month, 17),
      status: status,
      totalCents: total,
      paidCents: paid,
    );
  }

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

  test('dayMonth is day and month', () {
    expect(dayMonth(DateTime(2026, 10, 17)), '17/10');
    expect(dayMonth(DateTime(2026, 1, 5)), '05/01');
  });

  group('InvoiceStatusChip', () {
    testWidgets('open is blue', (tester) async {
      await show(tester, InvoiceStatusChip(invoice: invoice(), today: today));

      final label = tester.widget<Text>(find.text('Aberta'));
      expect(label.style?.color, const Color(0xFF0B4BB3));
    });

    testWidgets('closed and still to pay is gold', (tester) async {
      await show(tester, InvoiceStatusChip(invoice: invoice(month: DateTime(2026, 10)), today: today));

      final label = tester.widget<Text>(find.text('Fechada'));
      expect(label.style?.color, AppColors.goldOnLight);
    });

    testWidgets('paid in part says so, in gold', (tester) async {
      await show(tester, InvoiceStatusChip(invoice: invoice(paid: 50000), today: today));

      final label = tester.widget<Text>(find.text('Parcialmente paga'));
      expect(label.style?.color, AppColors.goldOnLight);
    });

    testWidgets('paid is green', (tester) async {
      await show(
        tester,
        InvoiceStatusChip(invoice: invoice(status: InvoiceStatus.paid, paid: 184335), today: today),
      );

      final label = tester.widget<Text>(find.text('Paga'));
      expect(label.style?.color, AppColors.positive);
    });
  });

  group('InvoiceSummaryCard', () {
    late List<String> calls;

    setUp(() => calls = []);

    testWidgets('shows the title, the tag, the total and the three tiles', (tester) async {
      await show(
        tester,
        InvoiceSummaryCard(invoice: invoice(), currency: 'BRL', today: today, onPay: () {}, onOpen: () {}),
      );

      expect(find.text('Fatura de novembro'), findsOneWidget);
      expect(find.text('Aberta'), findsOneWidget);
      expect(find.text('R\$ 1.843,35'), findsOneWidget);
      expect(find.text('Fecha'), findsOneWidget);
      expect(find.text('10/11'), findsOneWidget);
      expect(find.text('Vence'), findsOneWidget);
      expect(find.text('17/11'), findsOneWidget);
      expect(find.text('Pago'), findsOneWidget);
      expect(find.text('R\$ 0,00'), findsOneWidget);
    });

    testWidgets('the buttons pay and open it', (tester) async {
      await show(
        tester,
        InvoiceSummaryCard(
          invoice: invoice(),
          currency: 'BRL',
          today: today,
          onPay: () => calls.add('pay'),
          onOpen: () => calls.add('open'),
        ),
      );

      await tester.tap(find.text('Pagar fatura'));
      await tester.tap(find.text('Ver compras'));

      expect(calls, ['pay', 'open']);
    });

    testWidgets('paid in part: what is still owed, and "Pagar o restante"', (tester) async {
      await show(
        tester,
        InvoiceSummaryCard(invoice: invoice(paid: 84335), currency: 'BRL', today: today, onPay: () {}),
      );

      expect(find.text('Falta R\$ 1.000,00'), findsOneWidget);
      expect(find.text('Pagar o restante'), findsOneWidget);
    });

    testWidgets('paid: no button to pay', (tester) async {
      await show(
        tester,
        InvoiceSummaryCard(
          invoice: invoice(status: InvoiceStatus.paid, paid: 184335),
          currency: 'BRL',
          today: today,
          onPay: () => calls.add('pay'),
          onOpen: () {},
        ),
      );

      expect(find.text('Pagar fatura'), findsNothing);
      expect(find.text('Ver compras'), findsOneWidget);
    });

    testWidgets('on the invoice screen: the card name and no "Ver compras"', (tester) async {
      await show(
        tester,
        InvoiceSummaryCard(invoice: invoice(), currency: 'BRL', today: today, cardName: 'Nubank', onPay: () {}),
      );

      expect(find.text('Nubank'), findsOneWidget);
      expect(find.text('Ver compras'), findsNothing);
      expect(find.text('Pagar fatura'), findsOneWidget);
    });

    testWidgets('while paying, a bar instead of the buttons', (tester) async {
      await show(
        tester,
        InvoiceSummaryCard(invoice: invoice(), currency: 'BRL', today: today, onPay: () {}, paying: true),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Pagar fatura'), findsNothing);
    });

    testWidgets('works in the dark theme', (tester) async {
      await show(
        tester,
        InvoiceSummaryCard(invoice: invoice(paid: 84335), currency: 'BRL', today: today, onPay: () {}),
        theme: AppTheme.dark,
      );

      expect(find.text('Falta R\$ 1.000,00'), findsOneWidget);
    });
  });

  group('InvoiceRow', () {
    testWidgets('shows the month, when it is due, the total and the tag', (tester) async {
      await show(
        tester,
        InvoiceRow(invoice: invoice(month: DateTime(2026, 10)), currency: 'BRL', today: today, onTap: () {}),
      );

      expect(find.text('Outubro'), findsOneWidget);
      expect(find.text('Vence em 17/10/2026'), findsOneWidget);
      expect(find.text('R\$ 1.843,35'), findsOneWidget);
      expect(find.text('Fechada'), findsOneWidget);
    });

    testWidgets('a paid one says when it was due', (tester) async {
      await show(
        tester,
        InvoiceRow(
          invoice: invoice(month: DateTime(2026, 9), status: InvoiceStatus.paid, paid: 184335),
          currency: 'BRL',
          today: today,
          onTap: () {},
        ),
      );

      expect(find.text('Venceu em 17/09/2026'), findsOneWidget);
      expect(find.text('Paga'), findsOneWidget);
    });

    testWidgets('paid in part shows what is still owed', (tester) async {
      await show(
        tester,
        InvoiceRow(invoice: invoice(month: DateTime(2026, 9), status: InvoiceStatus.closed, paid: 172335), currency: 'BRL', today: today, onTap: () {}),
      );

      expect(find.text('Falta R\$ 120,00'), findsOneWidget);
    });

    testWidgets('a tap opens it', (tester) async {
      var taps = 0;
      await show(tester, InvoiceRow(invoice: invoice(), currency: 'BRL', today: today, onTap: () => taps++));

      await tester.tap(find.text('Novembro'));

      expect(taps, 1);
    });
  });

  group('PurchaseRow', () {
    TransactionEntity purchase({TransactionStatus status = TransactionStatus.posted, TransactionType type = TransactionType.expense}) {
      return TransactionEntity(
        id: 't1',
        workspaceId: 'w1',
        accountId: 'card',
        categoryId: null,
        type: type,
        status: status,
        amountCents: 43330,
        currency: 'BRL',
        description: 'Notebook (2/10)',
        occurredAt: DateTime(2026, 10, 6, 12),
      );
    }

    testWidgets('shows the description, the day and the amount', (tester) async {
      await show(tester, PurchaseRow(transaction: purchase()));

      expect(find.text('Notebook (2/10)'), findsOneWidget);
      expect(find.text('06/10/2026'), findsOneWidget);
      expect(find.text('- R\$ 433,30'), findsOneWidget);
    });

    testWidgets('a pending one says so', (tester) async {
      await show(tester, PurchaseRow(transaction: purchase(status: TransactionStatus.pending)));

      expect(find.text('06/10/2026 · Pendente'), findsOneWidget);
    });

    testWidgets('a refund is money in, in green', (tester) async {
      await show(tester, PurchaseRow(transaction: purchase(type: TransactionType.income)));

      final amount = tester.widget<Text>(find.text('+ R\$ 433,30'));
      expect(amount.style?.color, AppColors.positive);
    });
  });
}
