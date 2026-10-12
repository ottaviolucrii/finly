import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/ai/domain/entities/ask_turn.dart';
import 'package:finly/features/assistant/presentation/amora.dart';
import 'package:finly/features/assistant/presentation/amora_tips.dart';
import 'package:finly/features/assistant/presentation/widgets/amora_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tip = AmoraTip('Faltam R\$ 420 em Mercado.', AmoraMood.happy);

  late bool allowed;
  late Either<Failure, String> answer;
  late List<String> asked;
  late List<List<AskTurn>> histories;

  setUp(() {
    allowed = false;
    answer = const Right('Você gastou R\$ 812,40 com Uber em 2026, em 31 lançamentos.');
    asked = [];
    histories = [];
  });

  Future<void> open(WidgetTester tester, {bool withAsk = true}) async {
    tester.view.physicalSize = const Size(400, 1000);
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
              onWrite: () {},
              shortcuts: const [],
              ask: !withAsk
                  ? null
                  : AmoraAsk(
                      ask: (question, history) async {
                        asked.add(question);
                        histories.add(history);
                        return answer;
                      },
                      isEnabled: () async => Right(allowed),
                      enable: () async {
                        allowed = true;
                        return const Right(null);
                      },
                    ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> openQuestions(WidgetTester tester) async {
    await tester.tap(find.text('Perguntar sobre meu dinheiro'));
    await tester.pumpAndSettle();
  }

  testWidgets('without the AI it stays "Em breve"', (tester) async {
    await open(tester, withAsk: false);

    final tile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Perguntar sobre meu dinheiro'));
    expect(tile.enabled, isFalse);
  });

  testWidgets('the first time it asks for permission, saying only totals are shared', (tester) async {
    await open(tester);
    await openQuestions(tester);

    expect(find.textContaining('só esses totais vão para a IA'), findsOneWidget);
    await tester.tap(find.text('Permitir perguntas'));
    await tester.pumpAndSettle();

    expect(allowed, isTrue);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('"Agora não" goes back without allowing', (tester) async {
    await open(tester);
    await openQuestions(tester);

    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();

    expect(allowed, isFalse);
    expect(find.text('Oi! Sou a Amora.'), findsOneWidget);
  });

  testWidgets('a question gets Amora\'s answer', (tester) async {
    allowed = true;
    await open(tester);
    await openQuestions(tester);

    await tester.enterText(find.byType(TextField), 'quanto gastei com uber esse ano?');
    await tester.tap(find.byTooltip('Perguntar'));
    await tester.pumpAndSettle();

    expect(asked, ['quanto gastei com uber esse ano?']);
    expect(find.textContaining('R\$ 812,40 com Uber'), findsOneWidget);
  });

  testWidgets('an example asks with one tap', (tester) async {
    allowed = true;
    await open(tester);
    await openQuestions(tester);

    await tester.tap(find.text('Onde mais gastei este mês?'));
    await tester.pumpAndSettle();

    expect(asked, ['Onde mais gastei este mês?']);
  });

  testWidgets('when it cannot answer, it says why', (tester) async {
    allowed = true;
    answer = const Left(RuleFailure('ai_limit'));
    await open(tester);
    await openQuestions(tester);

    await tester.tap(find.text('Onde mais gastei este mês?'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Amanhã ela volta'), findsOneWidget);
  });

  testWidgets('a follow-up goes with the conversation, and both stay on screen', (tester) async {
    allowed = true;
    await open(tester);
    await openQuestions(tester);

    await tester.enterText(find.byType(TextField), 'quanto gastei com uber esse ano?');
    await tester.tap(find.byTooltip('Perguntar'));
    await tester.pumpAndSettle();
    answer = const Right('Em setembro foram R\$ 95,00.');
    await tester.enterText(find.byType(TextField), 'e no mês passado?');
    await tester.tap(find.byTooltip('Perguntar'));
    await tester.pumpAndSettle();

    expect(histories.first, isEmpty);
    expect(histories.last, [
      const AskTurn(question: 'quanto gastei com uber esse ano?', answer: 'Você gastou R\$ 812,40 com Uber em 2026, em 31 lançamentos.'),
    ]);
    expect(find.text('quanto gastei com uber esse ano?'), findsOneWidget);
    expect(find.text('e no mês passado?'), findsOneWidget);
    expect(find.text('Em setembro foram R\$ 95,00.'), findsOneWidget);
  });
}
