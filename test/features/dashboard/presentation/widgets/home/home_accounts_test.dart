import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/dashboard/presentation/widgets/home/home_accounts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AccountEntity account(String id, String name, int balance, {AccountType type = AccountType.checking}) => AccountEntity(
        id: id,
        workspaceId: 'w1',
        name: name,
        type: type,
        currency: 'BRL',
        openingBalanceCents: 0,
        postedBalanceCents: balance,
        projectedBalanceCents: balance,
      );

  final itau = account('a1', 'Itaú', 812040);
  final savings = account('a2', 'Poupança', 435995, type: AccountType.savings);
  final card = account('a3', 'Nubank', 0, type: AccountType.creditCard);

  late List<String> calls;

  setUp(() => calls = []);

  Future<void> show(WidgetTester tester, List<AccountEntity>? accounts, {bool hidden = false, ThemeData? theme}) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: HomeAccountsRow(
              accounts: accounts,
              hidden: hidden,
              onOpenAccount: (a) => calls.add('open ${a.name}'),
              onSeeAll: () => calls.add('all'),
              onNewAccount: () => calls.add('new'),
            ),
          ),
        ),
      ),
    );
  }

  test('credit cards are left out (they have their own place)', () {
    expect(homeAccounts([itau, card, savings]), [itau, savings]);
  });

  testWidgets('a spinner while the accounts load', (tester) async {
    await show(tester, null);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Ver todas'), findsNothing);
  });

  testWidgets('no accounts: a place to create the first', (tester) async {
    await show(tester, const []);

    await tester.tap(find.text('Criar a primeira conta'));

    expect(calls, ['new']);
  });

  testWidgets('one account: one wide card and "Nova conta"', (tester) async {
    await show(tester, [itau]);

    expect(find.text('Itaú'), findsOneWidget);
    expect(find.text('Conta corrente · a sua única conta'), findsOneWidget);
    expect(find.text('R\$ 8.120,40'), findsOneWidget);
    expect(find.text('Nova conta'), findsOneWidget);
  });

  testWidgets('several accounts: a card each, "Nova conta" and "Ver todas"', (tester) async {
    await show(tester, [itau, savings]);

    expect(find.text('Itaú'), findsOneWidget);
    expect(find.text('Poupança'), findsNWidgets(2));
    expect(find.text('R\$ 4.359,95'), findsOneWidget);
    expect(find.text('Nova conta'), findsOneWidget);
    expect(find.text('Ver todas'), findsOneWidget);
  });

  testWidgets('a tap opens the account; the links do their job', (tester) async {
    await show(tester, [itau, savings]);

    await tester.tap(find.text('Itaú'));
    await tester.tap(find.text('Ver todas'));
    await tester.tap(find.text('Nova conta'));

    expect(calls, ['open Itaú', 'all', 'new']);
  });

  testWidgets('hidden values hide the balances too', (tester) async {
    await show(tester, [itau, savings], hidden: true);

    expect(find.text('R\$ 8.120,40'), findsNothing);
    expect(find.text('R\$ ••••••'), findsNWidgets(2));
  });

  testWidgets('a negative balance is red', (tester) async {
    await show(tester, [account('a9', 'Conta', -5000), savings]);

    final balance = tester.widget<Text>(find.text('-R\$ 50,00'));
    expect(balance.style?.color, AppTheme.light.colorScheme.error);
  });

  testWidgets('a screen reader hears the account and its balance', (tester) async {
    await show(tester, [itau, savings]);

    expect(
      find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Conta Itaú, saldo R\$ 8.120,40. Abrir o extrato desta conta'),
      findsOneWidget,
    );
  });

  testWidgets('works in the dark theme', (tester) async {
    await show(tester, [itau, savings], theme: AppTheme.dark);

    expect(find.text('Itaú'), findsOneWidget);
  });
}
