import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/presentation/statement_filters.dart';
import 'package:finly/features/transactions/presentation/widgets/statement_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const account = AccountEntity(
    id: 'a1',
    workspaceId: 'w1',
    name: 'Itaú',
    type: AccountType.checking,
    currency: 'BRL',
    openingBalanceCents: 0,
    postedBalanceCents: 0,
    projectedBalanceCents: 0,
  );
  const category = CategoryEntity(
    id: 'c1',
    workspaceId: 'w1',
    name: 'Mercado',
    kind: CategoryKind.expense,
    icon: 'shopping_cart',
    colorHex: '#F29D38',
    isDefault: true,
  );

  TransactionEntity transaction({
    TransactionType type = TransactionType.expense,
    TransactionStatus status = TransactionStatus.posted,
    String? categoryId = 'c1',
    String? transferId,
  }) {
    return TransactionEntity(
      id: 't1',
      workspaceId: 'w1',
      accountId: 'a1',
      categoryId: categoryId,
      type: type,
      status: status,
      amountCents: 14230,
      currency: 'BRL',
      description: 'Supermercado Dia',
      occurredAt: DateTime(2026, 10, 10, 12),
      transferId: transferId,
    );
  }

  Future<void> show(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: Scaffold(body: child)));
  }

  group('QuickFilterChips', () {
    testWidgets('shows the four chips and marks the selected one', (tester) async {
      await show(tester, QuickFilterChips(selected: QuickFilter.expense, onSelected: (_) {}));

      for (final label in ['Tudo', 'Entradas', 'Saídas', 'Pendentes']) {
        expect(find.text(label), findsOneWidget);
      }
      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
      expect(chips.map((chip) => chip.selected), [false, false, true, false]);
    });

    testWidgets('a tap picks a chip', (tester) async {
      final picked = <QuickFilter>[];
      await show(tester, QuickFilterChips(selected: QuickFilter.all, onSelected: picked.add));

      await tester.tap(find.text('Pendentes'));
      await tester.tap(find.text('Entradas'));

      expect(picked, [QuickFilter.pending, QuickFilter.income]);
    });

    testWidgets('no chip is marked when none matches', (tester) async {
      await show(tester, QuickFilterChips(selected: null, onSelected: (_) {}));

      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
      expect(chips.every((chip) => !chip.selected), isTrue);
    });
  });

  group('statementSubtitle', () {
    test('category and account', () {
      expect(statementSubtitle(transaction(), category, account), 'Mercado · Itaú');
    });

    test('a transfer, an archived category and none', () {
      expect(statementSubtitle(transaction(categoryId: null, transferId: 'tr1'), null, account), 'Transferência · Itaú');
      expect(statementSubtitle(transaction(), null, account), 'Categoria arquivada · Itaú');
      expect(statementSubtitle(transaction(categoryId: null), null, null), 'Sem categoria · Conta');
    });
  });

  group('StatementDayGroup', () {
    testWidgets('shows the day in capitals over its rows, with lines between them', (tester) async {
      await show(
        tester,
        const StatementDayGroup(label: 'Hoje', rows: [Text('um'), Text('dois'), Text('três')]),
      );

      expect(find.text('HOJE'), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2));
    });
  });

  group('StatementRow', () {
    late List<String> calls;

    setUp(() => calls = []);

    Widget row(TransactionEntity t, {Future<bool> Function()? ask}) => StatementRow(
          transaction: t,
          account: account,
          category: category,
          onTap: () => calls.add('open'),
          onConfirm: () => calls.add('confirm'),
          onDelete: () => calls.add('delete'),
          confirmDelete: ask,
        );

    testWidgets('shows the description, the category, the account and the amount', (tester) async {
      await show(tester, row(transaction()));

      expect(find.text('Supermercado Dia'), findsOneWidget);
      expect(find.text('Mercado · Itaú'), findsOneWidget);
      expect(find.text('- R\$ 142,30'), findsOneWidget);
      expect(find.text('Pendente'), findsNothing);
    });

    testWidgets('money in is green with a plus sign', (tester) async {
      await show(tester, row(transaction(type: TransactionType.income)));

      final amount = tester.widget<Text>(find.text('+ R\$ 142,30'));
      expect(amount.style?.color, AppColors.positive);
    });

    testWidgets('a pending one has a tag and can be confirmed', (tester) async {
      await show(tester, row(transaction(status: TransactionStatus.pending)));

      expect(find.text('Pendente'), findsOneWidget);
      await tester.tap(find.text('Confirmar'));

      expect(calls, ['confirm']);
    });

    testWidgets('a tap opens it', (tester) async {
      await show(tester, row(transaction()));

      await tester.tap(find.text('Supermercado Dia'));

      expect(calls, ['open']);
    });

    testWidgets('there is no menu on each row (the row gives the text its room)', (tester) async {
      await show(tester, row(transaction()));

      expect(find.byTooltip('Mais opções'), findsNothing);
    });

    testWidgets('a swipe asks first when asked to, and stops on no', (tester) async {
      await show(tester, ListView(children: [row(transaction(transferId: 'tr1'), ask: () async => false)]));

      await tester.drag(find.text('Supermercado Dia'), const Offset(-800, 0));
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
      expect(find.text('Supermercado Dia'), findsOneWidget);
    });

    testWidgets('a swipe to the left deletes it', (tester) async {
      var visible = true;
      await show(
        tester,
        StatefulBuilder(
          builder: (context, setState) => ListView(
            children: [
              if (visible)
                StatementRow(
                  transaction: transaction(),
                  account: account,
                  category: category,
                  onTap: () {},
                  onConfirm: () {},
                  onDelete: () {
                    calls.add('delete');
                    // The page removes a deleted row from the list.
                    setState(() => visible = false);
                  },
                ),
            ],
          ),
        ),
      );

      await tester.drag(find.text('Supermercado Dia'), const Offset(-800, 0));
      await tester.pumpAndSettle();

      expect(calls, ['delete']);
      expect(find.text('Supermercado Dia'), findsNothing);
    });

    testWidgets('works in the dark theme', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark, home: Scaffold(body: row(transaction(status: TransactionStatus.pending)))),
      );

      expect(find.text('Pendente'), findsOneWidget);
    });
  });
}
