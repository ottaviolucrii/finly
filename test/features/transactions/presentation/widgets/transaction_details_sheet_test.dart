import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/presentation/widgets/transaction_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const account = AccountEntity(
    id: 'a1',
    workspaceId: 'w1',
    name: 'C6 Ottávio Conta Corrente Principal',
    type: AccountType.checking,
    currency: 'BRL',
    openingBalanceCents: 0,
    postedBalanceCents: 0,
    projectedBalanceCents: 0,
  );

  TransactionEntity transaction({
    TransactionStatus status = TransactionStatus.posted,
    TransactionType type = TransactionType.expense,
    String? transferId,
  }) =>
      TransactionEntity(
        id: 't1',
        workspaceId: 'w1',
        accountId: 'a1',
        categoryId: null,
        type: type,
        status: status,
        amountCents: 32000,
        currency: 'BRL',
        description: 'Pagamento fatura 11/2026 do cartão Visa Empresa Gold',
        occurredAt: DateTime(2026, 10, 11, 14, 5),
        transferId: transferId,
      );

  TransactionAction? chosen;

  Future<void> open(WidgetTester tester, TransactionEntity item) async {
    chosen = null;
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                chosen = await showTransactionDetails(context, transaction: item, account: account),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows everything in full', (tester) async {
    await open(tester, transaction());

    expect(find.text('Pagamento fatura 11/2026 do cartão Visa Empresa Gold'), findsOneWidget);
    expect(find.text('C6 Ottávio Conta Corrente Principal'), findsOneWidget);
    expect(find.text('11/10/2026 às 14:05'), findsOneWidget);
    expect(find.text('Confirmada'), findsOneWidget);
    expect(find.text('Sem categoria'), findsOneWidget);
  });

  testWidgets('edit and delete come back as the choice', (tester) async {
    await open(tester, transaction());
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(chosen, TransactionAction.edit);

    await open(tester, transaction());
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(chosen, TransactionAction.delete);
  });

  testWidgets('a pending one can be confirmed', (tester) async {
    await open(tester, transaction(status: TransactionStatus.pending));

    expect(find.textContaining('Pendente'), findsOneWidget);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(chosen, TransactionAction.confirm);
  });

  testWidgets('a transfer cannot be edited, only deleted', (tester) async {
    await open(tester, transaction(transferId: 'tr1'));

    expect(find.text('Editar'), findsNothing);
    expect(find.text('Excluir'), findsOneWidget);
    expect(find.text('Transferência'), findsOneWidget);
  });

  testWidgets('a receipt can be attached from the details', (tester) async {
    await open(tester, transaction());

    expect(find.text('Nenhum'), findsOneWidget);
    await tester.tap(find.text('Anexar comprovante'));
    await tester.pumpAndSettle();

    expect(chosen, TransactionAction.receipt);
  });
}
