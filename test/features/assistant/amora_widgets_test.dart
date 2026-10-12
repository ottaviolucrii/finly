import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/assistant/presentation/amora.dart';
import 'package:finly/features/assistant/presentation/amora_shortcuts.dart';
import 'package:finly/features/assistant/presentation/amora_tips.dart';
import 'package:finly/features/assistant/presentation/widgets/amora_helper.dart';
import 'package:finly/features/assistant/presentation/widgets/amora_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tip = AmoraTip('Faltam R\$ 420 em Mercado.', AmoraMood.happy);

  setUp(() => AmoraHelper.bubbleShown = false);

  Future<void> show(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: Scaffold(body: Center(child: child))));
  }

  group('AmoraHelper', () {
    testWidgets('the first time, the tip shows in a bubble and goes away', (tester) async {
      await show(tester, AmoraHelper(tip: tip, onOpen: () {}, bubbleTime: const Duration(milliseconds: 300)));

      expect(find.text(tip.text), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text(tip.text), findsNothing);
    });

    testWidgets('only once per session', (tester) async {
      AmoraHelper.bubbleShown = true;
      await show(tester, AmoraHelper(tip: tip, onOpen: () {}));

      expect(find.text(tip.text), findsNothing);
    });

    testWidgets('no bubble for the plain tip about the app', (tester) async {
      await show(tester, AmoraHelper(tip: amoraIdleTip, onOpen: () {}));

      expect(find.text(amoraIdleTip.text), findsNothing);
    });

    testWidgets('a tap opens her help', (tester) async {
      var opens = 0;
      await show(tester, AmoraHelper(tip: tip, onOpen: () => opens++, bubbleTime: const Duration(milliseconds: 10)));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Amora, sua ajudante. Abrir ajuda'));
      expect(opens, 1);
    });
  });

  group('AmoraSheet', () {
    late List<String> calls;

    setUp(() => calls = []);

    Future<void> openSheet(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAmoraSheet(
                context,
                tip: tip,
                onWrite: () => calls.add('write'),
                shortcuts: [
                  AmoraShortcut(
                    title: 'Pagar fatura',
                    hint: 'A fatura do cartão',
                    icon: Icons.receipt_long_outlined,
                    keywords: const ['fatura', 'pagar'],
                    onOpen: () => calls.add('fatura'),
                  ),
                  AmoraShortcut(
                    title: 'Metas',
                    hint: 'Guardar dinheiro',
                    icon: Icons.flag_outlined,
                    keywords: const ['objetivo'],
                    onOpen: () => calls.add('metas'),
                  ),
                ],
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('says hello and shows the tip of the day', (tester) async {
      await openSheet(tester);

      expect(find.text('Oi! Sou a Amora.'), findsOneWidget);
      expect(find.textContaining('Faltam R\$ 420'), findsOneWidget);
    });

    testWidgets('"Lançar escrevendo" closes the sheet and opens the "+"', (tester) async {
      await openSheet(tester);

      await tester.tap(find.text('Lançar escrevendo'));
      await tester.pumpAndSettle();

      expect(calls, ['write']);
      expect(find.text('Oi! Sou a Amora.'), findsNothing);
    });

    testWidgets('finds a place of the app and takes you there', (tester) async {
      await openSheet(tester);

      await tester.tap(find.text('Encontrar uma função'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'como pago a fatura?');
      await tester.pump();

      expect(find.text('Pagar fatura'), findsOneWidget);
      expect(find.text('Metas'), findsNothing);

      await tester.tap(find.text('Pagar fatura'));
      await tester.pumpAndSettle();
      expect(calls, ['fatura']);
    });

    testWidgets('asking about your money is coming soon (not tappable)', (tester) async {
      await openSheet(tester);

      final tile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Perguntar sobre meu dinheiro'));
      expect(tile.enabled, isFalse);
      expect(find.text('Em breve'), findsOneWidget);
    });
  });
}
