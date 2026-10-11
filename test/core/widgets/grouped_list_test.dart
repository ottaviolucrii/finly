import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/core/widgets/grouped_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(WidgetTester tester, Widget child, {ThemeData? theme}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Scaffold(body: ListView(padding: const EdgeInsets.all(20), children: [child])),
      ),
    );
  }

  group('GroupedSection', () {
    testWidgets('shows its label in capitals and its rows', (tester) async {
      await show(
        tester,
        const GroupedSection(
          label: 'Dinheiro',
          items: [
            GroupedItem(icon: Icons.account_balance_wallet_outlined, title: 'Contas', subtitle: 'Itaú, Poupança'),
            GroupedItem(icon: Icons.credit_card, title: 'Cartões'),
          ],
        ),
      );

      expect(find.text('DINHEIRO'), findsOneWidget);
      expect(find.text('Contas'), findsOneWidget);
      expect(find.text('Itaú, Poupança'), findsOneWidget);
      expect(find.text('Cartões'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    });

    testWidgets('puts a thin line between rows, not around them', (tester) async {
      await show(
        tester,
        const GroupedSection(items: [
          GroupedItem(icon: Icons.bar_chart, title: 'Um'),
          GroupedItem(icon: Icons.bar_chart, title: 'Dois'),
          GroupedItem(icon: Icons.bar_chart, title: 'Três'),
        ]),
      );

      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('a tap on a row calls it', (tester) async {
      var taps = 0;
      await show(
        tester,
        GroupedSection(items: [GroupedItem(icon: Icons.bar_chart, title: 'Relatórios', onTap: () => taps++)]),
      );

      await tester.tap(find.text('Relatórios'));

      expect(taps, 1);
    });

    testWidgets('a destructive row is red and has no arrow', (tester) async {
      await show(
        tester,
        const GroupedSection(items: [GroupedItem(icon: Icons.logout, title: 'Sair', danger: true)]),
      );

      final title = tester.widget<Text>(find.text('Sair'));
      expect(title.style?.color, AppTheme.light.colorScheme.error);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('has no label when none is given', (tester) async {
      await show(tester, const GroupedSection(items: [GroupedItem(icon: Icons.logout, title: 'Sair')]));

      expect(find.byType(SectionLabel), findsNothing);
    });
  });

  group('IconBadge', () {
    testWidgets('is a tinted circle with the primary color', (tester) async {
      await show(tester, const IconBadge(icon: Icons.bar_chart));

      final icon = tester.widget<Icon>(find.byIcon(Icons.bar_chart));
      expect(icon.color, AppTheme.light.colorScheme.primary);
    });

    testWidgets('is red for a destructive row', (tester) async {
      await show(tester, const IconBadge(icon: Icons.logout, danger: true));

      expect(tester.widget<Icon>(find.byIcon(Icons.logout)).color, AppTheme.light.colorScheme.error);
    });

    testWidgets('works in the dark theme', (tester) async {
      await show(tester, const IconBadge(icon: Icons.bar_chart), theme: AppTheme.dark);

      expect(tester.widget<Icon>(find.byIcon(Icons.bar_chart)).color, AppTheme.dark.colorScheme.primary);
    });
  });

  group('TabHeader', () {
    testWidgets('shows the small line in capitals and the big title', (tester) async {
      await show(tester, const TabHeader(kicker: 'Sua conta', title: 'Mais'));

      expect(find.text('SUA CONTA'), findsOneWidget);
      expect(find.text('Mais'), findsOneWidget);
    });

    testWidgets('the title is a heading for screen readers', (tester) async {
      await show(tester, const TabHeader(kicker: 'Sua conta', title: 'Mais'));

      final heading = find.ancestor(
        of: find.text('Mais'),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && (widget.properties.header ?? false),
        ),
      );
      expect(heading, findsOneWidget);
    });

    testWidgets('the small line is not part of the heading', (tester) async {
      await show(tester, const TabHeader(kicker: 'Sua conta', title: 'Mais'));

      final kickerInHeading = find.ancestor(
        of: find.text('SUA CONTA'),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && (widget.properties.header ?? false),
        ),
      );
      expect(kickerInHeading, findsNothing);
    });
  });
}
