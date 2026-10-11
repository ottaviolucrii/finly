import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/core/widgets/finly_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<FinlyTab> selected;
  late int adds;

  setUp(() {
    selected = [];
    adds = 0;
  });

  Future<void> show(WidgetTester tester, {FinlyTab current = FinlyTab.home, bool canAdd = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          bottomNavigationBar: FinlyTabBar(
            current: current,
            onSelect: selected.add,
            onAdd: canAdd ? () => adds++ : null,
          ),
        ),
      ),
    );
  }

  testWidgets('shows the four places', (tester) async {
    await show(tester);

    for (final label in ['Início', 'Extrato', 'Planejar', 'Mais']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('says which place is open to a screen reader', (tester) async {
    await show(tester, current: FinlyTab.plan);

    final plan = semanticsLabelled(tester, 'Planejar');
    expect(plan.button, isTrue);
    expect(plan.selected, isTrue);
    expect(plan.onTap, isNotNull);

    final home = semanticsLabelled(tester, 'Início');
    expect(home.button, isTrue);
    expect(home.selected, isFalse);
    expect(home.onTap, isNotNull);
  });

  testWidgets('a screen reader can press a place, and the "+"', (tester) async {
    await show(tester);

    semanticsLabelled(tester, 'Mais').onTap!();
    semanticsLabelled(tester, 'Novo lançamento').onTap!();

    expect(selected, [FinlyTab.more]);
    expect(adds, 1);
  });

  testWidgets('tapping a place asks for it', (tester) async {
    await show(tester);

    await tester.tap(find.text('Extrato'));
    await tester.tap(find.text('Planejar'));
    await tester.tap(find.text('Mais'));
    await tester.tap(find.text('Início'));

    expect(selected, [FinlyTab.statement, FinlyTab.plan, FinlyTab.more, FinlyTab.home]);
  });

  testWidgets('the selected place uses the primary color', (tester) async {
    await show(tester, current: FinlyTab.statement);

    final label = tester.widget<Text>(find.text('Extrato'));
    final other = tester.widget<Text>(find.text('Mais'));

    expect(label.style?.color, AppTheme.light.colorScheme.primary);
    expect(other.style?.color, AppTheme.light.colorScheme.onSurfaceVariant);
    expect(label.style?.fontWeight, FontWeight.w600);
  });

  testWidgets('the "+" adds a transaction', (tester) async {
    await show(tester);

    await tester.tap(find.byIcon(Icons.add));

    expect(adds, 1);
    expect(selected, isEmpty);
  });

  testWidgets('the "+" does nothing while it cannot be used', (tester) async {
    await show(tester, canAdd: false);

    await tester.tap(find.byIcon(Icons.add));

    expect(adds, 0);
  });

  testWidgets('the selected place shows its filled icon', (tester) async {
    await show(tester, current: FinlyTab.home);

    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
  });
}

/// The properties a [Semantics] widget gives to screen readers, found by its label.
SemanticsProperties semanticsLabelled(WidgetTester tester, String label) {
  return tester
      .widget<Semantics>(
        find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label),
      )
      .properties;
}
