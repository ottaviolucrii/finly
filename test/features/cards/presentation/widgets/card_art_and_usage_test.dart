import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/presentation/widgets/card_art.dart';
import 'package:finly/features/cards/presentation/widgets/card_usage_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CreditCardEntity card({int used = 184335, int limit = 500000}) => CreditCardEntity(
        accountId: 'c1',
        workspaceId: 'w1',
        name: 'Nubank',
        currency: 'BRL',
        limitCents: limit,
        closingDay: 10,
        dueDay: 17,
        usedCents: used,
      );

  Future<void> show(WidgetTester tester, Widget child, {ThemeData? theme}) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Scaffold(body: ListView(padding: const EdgeInsets.all(20), children: [child])),
      ),
    );
  }

  group('CardArt', () {
    testWidgets('shows the name, the days and the limit', (tester) async {
      await show(tester, CardArt(card: card()));

      expect(find.text('Nubank'), findsOneWidget);
      expect(find.text('Fecha dia 10 · vence dia 17'), findsOneWidget);
      expect(find.text('Limite R\$ 5.000,00'), findsOneWidget);
      expect(find.text('Crédito'), findsOneWidget);
    });

    testWidgets('a screen reader hears it in one sentence', (tester) async {
      await show(tester, CardArt(card: card(), onTap: () {}));

      final semantics = tester
          .widget<Semantics>(find.byWidgetPredicate((w) => w is Semantics && (w.properties.label ?? '').startsWith('Cartão Nubank')))
          .properties;
      expect(semantics.label, 'Cartão Nubank. Fecha dia 10 · vence dia 17. Limite R\$ 5.000,00');
      expect(semantics.button, isTrue);
    });

    testWidgets('a tap opens the card', (tester) async {
      var taps = 0;
      await show(tester, CardArt(card: card(), onTap: () => taps++));

      await tester.tap(find.text('Nubank'));

      expect(taps, 1);
    });

    testWidgets('without a tap it is not a button', (tester) async {
      await show(tester, CardArt(card: card()));

      final SemanticsProperties semantics = tester
          .widget<Semantics>(find.byWidgetPredicate((w) => w is Semantics && (w.properties.label ?? '').startsWith('Cartão Nubank')))
          .properties;
      expect(semantics.button, isFalse);
    });
  });

  group('CardUsageSummary', () {
    testWidgets('shows what is in use and what is free', (tester) async {
      await show(tester, CardUsageSummary(card: card()));

      expect(find.text('Em uso R\$ 1.843,35'), findsOneWidget);
      expect(find.text('Livre R\$ 3.156,65'), findsOneWidget);
      expect(find.text('Perto do limite'), findsNothing);
    });

    testWidgets('warns near the limit, in words', (tester) async {
      await show(tester, CardUsageSummary(card: card(used: 420000)));

      expect(find.text('Perto do limite'), findsOneWidget);
    });

    testWidgets('over the limit, nothing is free and it says so', (tester) async {
      await show(tester, CardUsageSummary(card: card(used: 520000)));

      expect(find.text('Livre R\$ 0,00'), findsOneWidget);
      expect(find.text('Acima do limite'), findsOneWidget);
      final label = tester.widget<Text>(find.text('Acima do limite'));
      expect(label.style?.color, AppTheme.light.colorScheme.error);
    });

    testWidgets('works in the dark theme', (tester) async {
      await show(tester, CardUsageSummary(card: card(used: 420000)), theme: AppTheme.dark);

      expect(find.text('Perto do limite'), findsOneWidget);
    });
  });
}
