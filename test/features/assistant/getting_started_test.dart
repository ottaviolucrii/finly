import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/assistant/presentation/getting_started.dart';
import 'package:finly/features/assistant/presentation/widgets/getting_started_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keeps the choices in memory, like the phone would.
class MemoryStore implements GettingStartedStore {
  final hidden = <String, bool>{};
  final skippedSteps = <String, Set<StartStep>>{};

  @override
  Future<bool> isHidden(String workspaceId) async => hidden[workspaceId] ?? false;

  @override
  Future<void> setHidden(String workspaceId, bool value) async {
    hidden[workspaceId] = value;
    GettingStartedStore.changes.value++;
  }

  @override
  Future<Set<StartStep>> skipped(String workspaceId) async => skippedSteps[workspaceId] ?? {};

  @override
  Future<void> skip(String workspaceId, StartStep step) async =>
      skippedSteps[workspaceId] = {...?skippedSteps[workspaceId], step};
}

void main() {
  test('the steps done come from what Início knows', () {
    expect(
      startStepsDone(hasAccount: true, hasTransaction: false, hasCard: true, hasBudget: false, hasGoal: false),
      {StartStep.account, StartStep.card},
    );
  });

  test('the first two steps cannot be skipped one by one', () {
    expect(StartStep.account.skipLabel, isNull);
    expect(StartStep.transaction.skipLabel, isNull);
    expect(StartStep.card.skipLabel, 'Não tenho cartão');
  });

  late MemoryStore store;
  late List<StartStep> opened;

  setUp(() {
    store = MemoryStore();
    opened = [];
  });

  Future<void> show(WidgetTester tester, Set<StartStep> done, {bool ready = true}) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListView(
            children: [
              GettingStartedCard(workspaceId: 'w1', done: done, ready: ready, store: store, onOpen: opened.add),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('nothing while Início is still reading', (tester) async {
    await show(tester, const {}, ready: false);

    expect(find.text('Primeiros passos'), findsNothing);
  });

  testWidgets('shows the steps and how many are done', (tester) async {
    await show(tester, {StartStep.account});

    expect(find.text('Primeiros passos'), findsOneWidget);
    expect(find.textContaining('1 de 5'), findsOneWidget);
    expect(find.text('Faça seu primeiro lançamento'), findsOneWidget);
  });

  testWidgets('a tap on a step takes you there', (tester) async {
    await show(tester, const {});

    await tester.tap(find.text('Defina um orçamento'));

    expect(opened, [StartStep.budget]);
  });

  testWidgets('a step that does not apply can be skipped, and counts', (tester) async {
    await show(tester, {StartStep.account});

    await tester.tap(find.text('Não tenho cartão'));
    await tester.pumpAndSettle();

    expect(store.skippedSteps['w1'], {StartStep.card});
    expect(find.textContaining('2 de 5'), findsOneWidget);
  });

  testWidgets('the whole guide can be skipped, and it says how to bring it back', (tester) async {
    await show(tester, const {});

    await tester.tap(find.byTooltip('Pular o guia'));
    await tester.pumpAndSettle();

    expect(store.hidden['w1'], isTrue);
    expect(find.text('Primeiros passos'), findsNothing);
    expect(find.textContaining('Encontrar uma função'), findsOneWidget);
  });

  testWidgets('a workspace already set up never shows it', (tester) async {
    await show(tester, StartStep.values.toSet());

    expect(find.text('Tudo pronto!'), findsNothing);
    expect(store.hidden['w1'], isTrue);
  });

  testWidgets('finishing the last step celebrates', (tester) async {
    final almost = StartStep.values.toSet()..remove(StartStep.goal);
    await show(tester, almost);
    expect(find.textContaining('4 de 5'), findsOneWidget);

    await show(tester, StartStep.values.toSet());

    expect(find.text('Tudo pronto!'), findsOneWidget);
  });
}
