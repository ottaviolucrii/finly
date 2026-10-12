import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/ai/presentation/widgets/ai_settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_ai_repository.dart';

void main() {
  late FakeAiRepository ai;

  setUp(() => ai = FakeAiRepository());

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: ListView(children: [AiSettingsCard(repository: ai)])),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool switchOn(WidgetTester tester) => tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value;

  testWidgets('starts as it is saved', (tester) async {
    ai.enabled = true;
    await show(tester);

    expect(switchOn(tester), isTrue);
  });

  testWidgets('turning it on asks first, and says what goes to the AI', (tester) async {
    await show(tester);

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    expect(find.text('Ligar a inteligência artificial?'), findsOneWidget);
    expect(find.textContaining('Nunca saldos'), findsOneWidget);

    await tester.tap(find.text('Ligar'));
    await tester.pumpAndSettle();

    expect(ai.changes, [true]);
    expect(switchOn(tester), isTrue);
  });

  testWidgets('"Agora não" changes nothing', (tester) async {
    await show(tester);

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();

    expect(ai.changes, isEmpty);
    expect(switchOn(tester), isFalse);
  });

  testWidgets('turning it off needs no question', (tester) async {
    ai.enabled = true;
    await show(tester);

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    expect(ai.changes, [false]);
    expect(switchOn(tester), isFalse);
  });

  testWidgets('if saving fails, the switch stays and it says so', (tester) async {
    ai.saveResult = const Left(NetworkFailure('x'));
    ai.enabled = true;
    await show(tester);

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    expect(switchOn(tester), isTrue);
    expect(find.textContaining('internet'), findsOneWidget);
  });

  group('questions about money', () {
    Finder askSwitch() => find.byType(SwitchListTile).last;
    bool askOn(WidgetTester tester) => tester.widget<SwitchListTile>(askSwitch()).value;

    testWidgets('allowing asks first, saying only totals go to the AI', (tester) async {
      await show(tester);

      await tester.tap(askSwitch());
      await tester.pumpAndSettle();
      expect(find.text('Permitir perguntas sobre seu dinheiro?'), findsOneWidget);
      expect(find.textContaining('nunca vê seus lançamentos'), findsOneWidget);

      await tester.tap(find.text('Permitir'));
      await tester.pumpAndSettle();

      expect(ai.askEnabled, isTrue);
      expect(askOn(tester), isTrue);
    });

    testWidgets('turning them off needs no question', (tester) async {
      ai.askEnabled = true;
      await show(tester);

      await tester.tap(askSwitch());
      await tester.pumpAndSettle();

      expect(ai.askEnabled, isFalse);
      expect(askOn(tester), isFalse);
    });
  });
}
