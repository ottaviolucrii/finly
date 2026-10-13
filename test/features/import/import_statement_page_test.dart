import 'dart:convert';

import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/import/data/import_source.dart';
import 'package:finly/features/import/domain/statement_line.dart';
import 'package:finly/features/import/presentation/import_statement_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSource implements ImportSource {
  final saved = <List<StatementLine>>[];
  final savedCategories = <List<String?>>[];
  Set<String> existing = {};

  @override
  Future<List<CategoryEntity>> categories(String workspaceId) async => const [
        CategoryEntity(
          id: 'c-food',
          workspaceId: 'w1',
          name: 'Alimentação',
          kind: CategoryKind.expense,
          icon: 'restaurant',
          colorHex: '#F29D38',
          isDefault: true,
        ),
      ];

  @override
  Future<Map<String, String>> suggestions(String workspaceId, List<String> descriptions, {required bool income}) async =>
      {for (final d in descriptions) if (!income && d.contains('Padaria')) d: 'c-food'};

  @override
  Future<ImportCheck> run(String accountId, List<StatementLine> lines, List<String?> categoryIds, {required bool save}) async {
    final statuses = [for (final l in lines) existing.contains(l.description) ? 'duplicate' : 'new'];
    if (save) {
      saved.add(lines);
      savedCategories.add(categoryIds);
    }
    return ImportCheck(
      statuses: statuses,
      newCount: statuses.where((s) => s == 'new').length,
      duplicates: statuses.where((s) => s == 'duplicate').length,
      paidInvoice: 0,
    );
  }
}

void main() {
  AccountEntity account(AccountType type) => AccountEntity(
        id: 'a1',
        workspaceId: 'w1',
        name: type == AccountType.creditCard ? 'Nubank' : 'Itaú',
        type: type,
        currency: 'BRL',
        openingBalanceCents: 0,
        postedBalanceCents: 0,
        projectedBalanceCents: 0,
      );

  const csv = 'Data,Valor,Identificador,Descrição\n'
      '01/10/2026,-25.90,f1,Padaria Pão Quente\n'
      '02/10/2026,-89.90,f2,Netflix\n'
      '03/10/2026,1500.00,f3,Pix recebido\n';

  late FakeSource source;
  Object? popped;

  setUp(() {
    source = FakeSource();
    popped = null;
  });

  Future<void> open(WidgetTester tester, {required String file, AccountType type = AccountType.checking}) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<ImportCheck>(
                MaterialPageRoute(
                  builder: (_) => ImportStatementPage(
                    account: account(type),
                    source: source,
                    pickFile: () async => (name: 'extrato.csv', bytes: utf8.encode(file)),
                  ),
                ),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows every line, what is new, and the suggested category', (tester) async {
    await open(tester, file: csv);

    expect(find.text('3 lançamentos em extrato.csv'), findsOneWidget);
    expect(find.textContaining('3 novos · 0 já estão no Finly'), findsOneWidget);
    expect(find.text('Padaria Pão Quente'), findsOneWidget);
    expect(find.text('Alimentação'), findsOneWidget);
    expect(find.text('Importar 3 lançamentos'), findsOneWidget);
  });

  testWidgets('lines already in Finly come unchecked and cannot be checked', (tester) async {
    source.existing = {'Netflix'};
    await open(tester, file: csv);

    expect(find.textContaining('2 novos · 1 já estão no Finly'), findsOneWidget);
    expect(find.textContaining('Já no Finly'), findsOneWidget);
    expect(find.text('Importar 2 lançamentos'), findsOneWidget);
  });

  testWidgets('unchecking a line leaves it out; saving sends the rest with their categories', (tester) async {
    await open(tester, file: csv);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    await tester.tap(find.text('Importar 2 lançamentos'));
    await tester.pumpAndSettle();

    expect(source.saved.single.map((l) => l.description), ['Padaria Pão Quente', 'Pix recebido']);
    expect(source.savedCategories.single, ['c-food', null]);
    expect((popped as ImportCheck).newCount, 2);
  });

  testWidgets('a card CSV with positive purchases turns them into expenses', (tester) async {
    await open(tester, file: 'date,title,amount\n2026-10-03,Netflix,39.90\n2026-10-04,iFood,52.00\n', type: AccountType.creditCard);

    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isTrue);
    expect(find.text('- R\$ 39,90'), findsOneWidget);
  });

  testWidgets('a file with nothing to read says so', (tester) async {
    await open(tester, file: 'a;b;c\n1;2;3\n');

    expect(find.textContaining('Não encontrei lançamentos'), findsOneWidget);
    expect(find.text('Escolher outro arquivo'), findsOneWidget);
  });
}
