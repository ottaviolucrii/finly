import 'package:finly/core/money/money.dart';
import 'package:finly/features/yield_simulator/presentation/pages/yield_simulator_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String money(int cents) => Money(cents, 'BRL').format();

  Future<void> show(WidgetTester tester) async {
    // A tall screen, so the whole page is built and nothing needs scrolling.
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: YieldSimulatorPage()));
    await tester.pump();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  group('termLabel', () {
    test('says years when the term is whole years', () {
      expect(termLabel(12), '1 ano');
      expect(termLabel(24), '2 anos');
      expect(termLabel(120), '10 anos');
    });

    test('says months otherwise', () {
      expect(termLabel(1), '1 mês');
      expect(termLabel(18), '18 meses');
      expect(termLabel(61), '61 meses');
    });
  });

  testWidgets('shows an example result at once', (tester) async {
    await show(tester);

    expect(find.text('Simulador de rendimento'), findsOneWidget);
    expect(find.text('Resultado em 5 anos'), findsOneWidget);
    expect(find.text('Total líquido'), findsOneWidget);
    expect(find.text('Total investido'), findsOneWidget);
    // 10.000,00 at the start and 500,00 for 60 months.
    expect(find.text(money(4000000)), findsWidgets);
    expect(find.text('Imposto de renda'), findsOneWidget);
  });

  testWidgets('says what the effective rate is', (tester) async {
    await show(tester);

    expect(find.text('Taxa efetiva: 13,65% ao ano'), findsOneWidget);
  });

  testWidgets('a different term changes the result', (tester) async {
    await show(tester);

    await tester.enterText(field('Prazo (meses)'), '12');
    await tester.pump();

    expect(find.text('Resultado em 1 ano'), findsOneWidget);
    // 10.000,00 + 12 x 500,00.
    expect(find.text(money(1600000)), findsWidgets);
  });

  testWidgets('the term chips fill in the term', (tester) async {
    await show(tester);

    await tester.tap(find.text('10 anos'));
    await tester.pump();

    expect(tester.widget<TextField>(field('Prazo (meses)')).controller!.text, '120');
    expect(find.text('Resultado em 10 anos'), findsOneWidget);
  });

  testWidgets('an exempt investment shows no tax', (tester) async {
    await show(tester);

    await tester.tap(find.text('Isento (LCI, LCA, poupança)'));
    await tester.pump();

    expect(find.text('Isento'), findsOneWidget);
  });

  testWidgets('a fixed rate replaces the CDI fields', (tester) async {
    await show(tester);

    await tester.tap(find.text('Taxa fixa'));
    await tester.pump();

    expect(field('Taxa (% ao ano)'), findsOneWidget);
    expect(field('CDI (% ao ano)'), findsNothing);
    expect(find.text('Taxa efetiva: 12% ao ano'), findsOneWidget);
  });

  testWidgets('a missing term shows an error and no result', (tester) async {
    await show(tester);

    await tester.enterText(field('Prazo (meses)'), '');
    await tester.pump();

    expect(find.text('Informe de 1 a 600 meses.'), findsOneWidget);
    expect(find.text('Total líquido'), findsNothing);
    expect(find.text('Preencha os campos acima para ver o resultado.'), findsOneWidget);
  });

  testWidgets('both deposits empty asks for one of them', (tester) async {
    await show(tester);

    await tester.enterText(field('Valor inicial'), '');
    await tester.enterText(field('Aporte mensal'), '');
    await tester.pump();

    expect(find.text('Informe um valor inicial ou um aporte mensal.'), findsOneWidget);
    expect(find.text('Total líquido'), findsNothing);
  });

  testWidgets('a CDI that is not a number shows an error', (tester) async {
    await show(tester);

    await tester.enterText(field('CDI (% ao ano)'), '');
    await tester.pump();

    expect(find.text('Informe o CDI (ex.: 13,65).'), findsOneWidget);
  });

  testWidgets('the yearly table has a row for each year and the end', (tester) async {
    await show(tester);

    await tester.enterText(field('Prazo (meses)'), '30');
    await tester.pump();

    final table = find.widgetWithText(Card, 'Ano a ano');
    Finder inTable(String label) => find.descendant(of: table, matching: find.text(label));

    expect(table, findsOneWidget);
    expect(inTable('1 ano'), findsOneWidget);
    expect(inTable('2 anos'), findsOneWidget);
    expect(inTable('30 meses'), findsOneWidget);
    expect(inTable('3 anos'), findsNothing);
  });

  testWidgets('explains the limits of the calculation', (tester) async {
    await show(tester);

    await tester.tap(find.text('Como calculamos'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Não é recomendação'), findsOneWidget);
  });
}
