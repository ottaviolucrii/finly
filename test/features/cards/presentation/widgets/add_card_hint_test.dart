import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/cards/presentation/widgets/card_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(WidgetTester tester, {required bool first, required VoidCallback onAdd, ThemeData? theme}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [AddCardHint(first: first, onAdd: onAdd)],
          ),
        ),
      ),
    );
  }

  testWidgets('with no card, invites to add the first', (tester) async {
    await show(tester, first: true, onAdd: () {});

    expect(find.text('Adicione o seu primeiro cartão'), findsOneWidget);
    expect(find.textContaining('Acompanhe o limite'), findsOneWidget);
  });

  testWidgets('with cards, offers one more', (tester) async {
    await show(tester, first: false, onAdd: () {});

    expect(find.text('Mais um cartão?'), findsOneWidget);
  });

  testWidgets('the button adds a card', (tester) async {
    var adds = 0;
    await show(tester, first: true, onAdd: () => adds++);

    await tester.tap(find.text('Cadastrar cartão'));

    expect(adds, 1);
  });

  testWidgets('works in the dark theme', (tester) async {
    await show(tester, first: true, onAdd: () {}, theme: AppTheme.dark);

    expect(find.text('Cadastrar cartão'), findsOneWidget);
  });
}
