import 'package:finly/core/money/money.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:finly/features/dashboard/presentation/widgets/home/home_band.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const brl = CurrencyBalance(currency: 'BRL', postedCents: 1248035, projectedCents: 987010, cardDebtCents: 234335);
  const plain = CurrencyBalance(currency: 'BRL', postedCents: 50000, projectedCents: 50000, cardDebtCents: 0);
  const usd = CurrencyBalance(currency: 'USD', postedCents: 12000, projectedCents: 12000, cardDebtCents: 0);

  late int toggles, profiles, switches, opens;

  setUp(() {
    toggles = 0;
    profiles = 0;
    switches = 0;
    opens = 0;
  });

  Future<void> show(
    WidgetTester tester, {
    List<CurrencyBalance>? balances = const [brl],
    bool hidden = false,
    bool canSwitch = true,
    bool hasAccounts = true,
    String label = 'Pessoal',
    bool canOpenAccounts = false,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeBand(
              workspaceLabel: label,
              onSwitchWorkspace: canSwitch ? () => switches++ : null,
              hidden: hidden,
              onToggleHidden: () => toggles++,
              initial: 'O',
              onProfile: () => profiles++,
              balances: balances,
              hasAccounts: hasAccounts,
              onOpenAccounts: canOpenAccounts ? () => opens++ : null,
            ),
          ),
        ),
      ),
    );
  }

  group('maskedMoney', () {
    test('shows the amount', () {
      expect(maskedMoney(const Money(1248035, 'BRL'), hidden: false), 'R\$ 12.480,35');
    });

    test('hides it, keeping the currency', () {
      expect(maskedMoney(const Money(1248035, 'BRL'), hidden: true), 'R\$ ••••••');
    });
  });

  testWidgets('shows the workspace, the balance and the two figures', (tester) async {
    await show(tester);

    expect(find.text('Pessoal'), findsOneWidget);
    expect(find.text('Saldo em contas'), findsOneWidget);
    expect(find.text('R\$ 12.480,35'), findsOneWidget);
    expect(find.text('Previsto'), findsOneWidget);
    expect(find.text('R\$ 9.870,10'), findsOneWidget);
    expect(find.text('Cartões'), findsOneWidget);
    expect(find.text('R\$ 2.343,35'), findsOneWidget);
  });

  testWidgets('hides every amount when asked', (tester) async {
    await show(tester, hidden: true);

    expect(find.text('R\$ 12.480,35'), findsNothing);
    expect(find.text('R\$ 9.870,10'), findsNothing);
    expect(find.text('R\$ ••••••'), findsNWidgets(3));
    expect(find.byTooltip('Mostrar valores'), findsOneWidget);
  });

  testWidgets('the eye asks to hide or show the values', (tester) async {
    await show(tester);

    await tester.tap(find.byTooltip('Esconder valores'));

    expect(toggles, 1);
  });

  testWidgets('the avatar opens the account and more', (tester) async {
    await show(tester);

    await tester.tap(find.text('O'));

    expect(profiles, 1);
  });

  testWidgets('the workspace opens the switch when there is another one', (tester) async {
    await show(tester);

    await tester.tap(find.text('Pessoal'));

    expect(switches, 1);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
  });

  testWidgets('with one workspace there is no arrow and nothing to switch', (tester) async {
    await show(tester, canSwitch: false);

    await tester.tap(find.text('Pessoal'));

    expect(switches, 0);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
  });

  testWidgets('shows no small figures when nothing is pending and no card is in use', (tester) async {
    await show(tester, balances: const [plain]);

    expect(find.text('Previsto'), findsNothing);
    expect(find.text('Cartões'), findsNothing);
  });

  testWidgets('shows a dash while the balance loads', (tester) async {
    await show(tester, balances: null);

    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('says where to create the first account', (tester) async {
    await show(tester, balances: const [], hasAccounts: false);

    expect(find.textContaining('Nenhuma conta ainda'), findsOneWidget);
  });

  testWidgets('shows the balance of other currencies under the main one', (tester) async {
    await show(tester, balances: const [plain, usd]);

    expect(find.text('R\$ 500,00'), findsOneWidget);
    expect(find.textContaining('120,00'), findsOneWidget);
  });

  testWidgets('a negative balance stands out in gold', (tester) async {
    await show(tester, balances: const [CurrencyBalance(currency: 'BRL', postedCents: -5000, projectedCents: -5000, cardDebtCents: 0)]);

    final balance = tester.widget<Text>(
      find.byWidgetPredicate((widget) => widget is Text && widget.style?.fontSize == 36),
    );
    expect(balance.style?.color, AppColors.goldOnBand);
  });

  testWidgets('shows the company workspace by its name', (tester) async {
    await show(tester, label: 'Empresa');

    expect(find.text('Empresa'), findsOneWidget);
  });

  testWidgets('a tap on the balance opens the accounts, with an arrow to say so', (tester) async {
    await show(tester, canOpenAccounts: true);

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    await tester.tap(find.text('R\$ 12.480,35'));

    expect(opens, 1);
  });

  testWidgets('without it, the balance is plain text', (tester) async {
    await show(tester);

    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });
}
