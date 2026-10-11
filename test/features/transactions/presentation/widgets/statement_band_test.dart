import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/dashboard/domain/entities/monthly_flow_entry.dart';
import 'package:finly/features/transactions/presentation/widgets/statement_band.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final october = DateTime(2026, 10);
  final totals = MonthlyFlowEntry(month: october, currency: 'BRL', incomeCents: 820000, expenseCents: 573190);

  late List<String> calls;

  setUp(() => calls = []);

  Future<void> show(
    WidgetTester tester, {
    StatementPeriod period = StatementPeriod.month,
    MonthlyFlowEntry? entry,
    bool loading = false,
    int filters = 0,
    bool back = false,
    bool searching = false,
  }) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatementBand(
            month: october,
            period: period,
            totals: entry,
            loadingTotals: loading,
            filterCount: filters,
            searching: searching,
            showBack: back,
            onPrevious: () => calls.add('previous'),
            onNext: () => calls.add('next'),
            onThisMonth: () => calls.add('this month'),
            onSearch: () => calls.add('search'),
            onFilters: () => calls.add('filters'),
            onTransfer: () => calls.add('transfer'),
            onTrash: () => calls.add('trash'),
          ),
        ),
      ),
    );
  }

  test('monthTitle writes the month in full', () {
    expect(monthTitle(DateTime(2026, 10)), 'Outubro de 2026');
    expect(monthTitle(DateTime(2027, 1)), 'Janeiro de 2027');
  });

  testWidgets('shows the title, the month and its totals', (tester) async {
    await show(tester, entry: totals);

    expect(find.text('Extrato'), findsOneWidget);
    expect(find.text('Outubro de 2026'), findsOneWidget);
    expect(find.text('R\$ 8.200,00'), findsOneWidget);
    expect(find.text('R\$ 5.731,90'), findsOneWidget);
    expect(find.text('Sobrou'), findsOneWidget);
    expect(find.text('+ R\$ 2.468,10'), findsOneWidget);
  });

  testWidgets('says the month was short when more went out', (tester) async {
    await show(tester, entry: MonthlyFlowEntry(month: october, currency: 'BRL', incomeCents: 100000, expenseCents: 150000));

    expect(find.text('Faltou'), findsOneWidget);
    expect(find.text('− R\$ 500,00'), findsOneWidget);
  });

  testWidgets('a month with nothing shows zeros', (tester) async {
    await show(tester);

    expect(find.text('R\$ 0,00'), findsNWidgets(2));
    expect(find.text('+ R\$ 0,00'), findsOneWidget);
  });

  testWidgets('shows dots while the totals load', (tester) async {
    await show(tester, loading: true);

    expect(find.text('…'), findsNWidgets(3));
  });

  testWidgets('the arrows move between months', (tester) async {
    await show(tester, entry: totals);

    await tester.tap(find.byTooltip('Mês anterior'));
    await tester.tap(find.byTooltip('Próximo mês'));

    expect(calls, ['previous', 'next']);
  });

  testWidgets('the buttons search, filter, transfer and open the trash', (tester) async {
    await show(tester, entry: totals);

    await tester.tap(find.byTooltip('Buscar'));
    await tester.tap(find.byTooltip('Filtros'));
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transferir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lixeira'));
    await tester.pumpAndSettle();

    expect(calls, ['search', 'filters', 'transfer', 'trash']);
  });

  testWidgets('the filters button shows how many are set', (tester) async {
    await show(tester, filters: 2);

    expect(find.byTooltip('Filtros, 2 ativos'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('while searching, the button closes the search', (tester) async {
    await show(tester, searching: true);

    expect(find.byTooltip('Fechar busca'), findsOneWidget);
  });

  testWidgets('a custom period has no arrows and offers this month', (tester) async {
    await show(tester, period: StatementPeriod.custom);

    expect(find.text('Período escolhido nos filtros'), findsOneWidget);
    expect(find.byTooltip('Mês anterior'), findsNothing);
    expect(find.text('Entradas'), findsNothing);

    await tester.tap(find.text('Ver este mês'));
    expect(calls, ['this month']);
  });

  testWidgets('all periods says so', (tester) async {
    await show(tester, period: StatementPeriod.all);

    expect(find.text('Todos os períodos'), findsOneWidget);
  });

  testWidgets('opened from another screen, it has a back arrow', (tester) async {
    await show(tester, back: true);

    expect(find.byTooltip('Voltar'), findsOneWidget);
  });

  testWidgets('as a tab, it has no back arrow', (tester) async {
    await show(tester);

    expect(find.byTooltip('Voltar'), findsNothing);
  });
}
