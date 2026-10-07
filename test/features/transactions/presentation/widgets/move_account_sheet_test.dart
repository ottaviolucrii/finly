import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/transactions/presentation/widgets/move_account_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AccountEntity account(
    String id,
    String name,
    int balance, {
    AccountType type = AccountType.checking,
  }) {
    return AccountEntity(
      id: id,
      workspaceId: 'w1',
      name: name,
      type: type,
      currency: 'BRL',
      openingBalanceCents: 0,
      postedBalanceCents: balance,
      projectedBalanceCents: balance,
    );
  }

  final reserve = account('a2', 'Reserva', 150000);
  final wallet = account('a3', 'Carteira', 2000);

  Future<void> show(WidgetTester tester, ValueChanged<AccountEntity> onSelected) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoveAccountSheet(
            targets: [reserve, wallet],
            currency: 'BRL',
            onSelected: onSelected,
          ),
        ),
      ),
    );
  }

  testWidgets('asks which account and says the rules', (tester) async {
    await show(tester, (_) {});

    expect(find.text('Mover para qual conta?'), findsOneWidget);
    expect(find.textContaining('em BRL'), findsOneWidget);
    expect(find.textContaining('descartadas'), findsOneWidget);
  });

  testWidgets('lists every account with its balance', (tester) async {
    await show(tester, (_) {});

    expect(find.text('Reserva'), findsOneWidget);
    expect(find.text('Carteira'), findsOneWidget);
    expect(find.textContaining('Saldo'), findsNWidgets(2));
  });

  testWidgets('tapping an account reports it', (tester) async {
    AccountEntity? picked;
    await show(tester, (account) => picked = account);

    await tester.tap(find.text('Carteira'));
    await tester.pump();

    expect(picked, wallet);
  });

  testWidgets('a credit card says it goes onto the invoice, with no balance', (tester) async {
    final card = account('c1', 'Visa', -30000, type: AccountType.creditCard);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoveAccountSheet(
            targets: [reserve, card],
            currency: 'BRL',
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Visa'), findsOneWidget);
    expect(find.textContaining('entra na fatura'), findsOneWidget);
    expect(find.textContaining('Saldo'), findsOneWidget);
    expect(find.byIcon(Icons.credit_card), findsOneWidget);
  });

  testWidgets('has a cancel button', (tester) async {
    await show(tester, (_) {});

    expect(find.text('Cancelar'), findsOneWidget);
  });
}
