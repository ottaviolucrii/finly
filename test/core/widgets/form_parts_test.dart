import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/core/widgets/form_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: child));
  }

  group('FormPage', () {
    testWidgets('shows the title, the fields and the save button', (tester) async {
      var saves = 0;
      await show(
        tester,
        FormPage(title: 'Nova conta', saveLabel: 'Criar conta', onSave: () => saves++, form: const Text('campos')),
      );

      expect(find.text('Nova conta'), findsOneWidget);
      expect(find.text('campos'), findsOneWidget);
      await tester.tap(find.text('Criar conta'));
      expect(saves, 1);
    });

    testWidgets('while saving, a spinner and no second save', (tester) async {
      var saves = 0;
      await show(
        tester,
        FormPage(title: 'Nova conta', saveLabel: 'Criar conta', saving: true, onSave: () => saves++, form: const SizedBox()),
      );

      expect(find.text('Criar conta'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      expect(saves, 0);
    });

    testWidgets('the ✕ closes the page', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FormPage(title: 'Nova conta', saveLabel: 'Criar', onSave: () {}, form: const SizedBox()),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();

      expect(find.text('Nova conta'), findsNothing);
    });
  });

  group('ChoicePills', () {
    testWidgets('marks the chosen one and picks another', (tester) async {
      final picked = <String>[];
      await show(
        tester,
        Scaffold(
          body: ChoicePills<String>(
            options: currencyPills,
            selected: 'BRL',
            onSelected: picked.add,
          ),
        ),
      );

      final real = tester.widget<Semantics>(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Real (R\$)'));
      expect(real.properties.selected, isTrue);

      await tester.tap(find.text('Euro (€)'));
      expect(picked, ['EUR']);
    });

    testWidgets('without onSelected nothing can be picked', (tester) async {
      await show(
        tester,
        const Scaffold(body: ChoicePills<String>(options: currencyPills, selected: 'BRL', onSelected: null)),
      );

      await tester.tap(find.text('Euro (€)'));
      // nothing to assert but that it did not throw
      expect(find.text('Euro (€)'), findsOneWidget);
    });
  });

  group('AmountCard', () {
    testWidgets('types like in bank apps and shows the currency', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await show(
        tester,
        Scaffold(
          body: AmountCard(
            label: 'Limite por mês',
            controller: controller,
            currency: 'BRL',
            footer: const Text('rodapé'),
          ),
        ),
      );

      expect(find.text('Limite por mês'), findsOneWidget);
      expect(find.text('rodapé'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '150000');
      expect(controller.text, '1.500,00');
    });
  });

  testWidgets('InfoBox shows its text', (tester) async {
    await show(
      tester,
      const Scaffold(body: InfoBox(icon: Icons.info_outline, text: 'Vale a partir de outubro')),
    );

    expect(find.text('Vale a partir de outubro'), findsOneWidget);
  });

  testWidgets('works in the dark theme', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: InfoBox(icon: Icons.info_outline, text: 'escuro')),
      ),
    );

    expect(find.text('escuro'), findsOneWidget);
  });
}
