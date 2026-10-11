import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/presentation/widgets/card_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CreditCardEntity card(String name) => CreditCardEntity(
        accountId: name,
        workspaceId: 'w1',
        name: name,
        currency: 'BRL',
        limitCents: 500000,
        closingDay: 10,
        dueDay: 17,
        usedCents: 0,
      );

  late PageController controller;
  late List<int> changes;
  late int adds;

  setUp(() {
    controller = PageController(viewportFraction: CardCarousel.viewportFraction);
    changes = [];
    adds = 0;
  });

  tearDown(() => controller.dispose());

  Future<void> show(WidgetTester tester, List<CreditCardEntity> cards, {int index = 0}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ListView(
              children: [
                CardCarousel(
                  cards: cards,
                  controller: controller,
                  index: index,
                  onChanged: (value) => setState(() {
                    changes.add(value);
                    index = value;
                  }),
                  onAdd: () => adds++,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the first card and the next one peeking in', (tester) async {
    await show(tester, [card('Nubank'), card('Itaú')]);

    expect(find.text('Nubank'), findsOneWidget);
    expect(find.text('Itaú'), findsOneWidget);
  });

  testWidgets('a swipe brings the next card to the front', (tester) async {
    await show(tester, [card('Nubank'), card('Itaú')]);

    await tester.drag(find.text('Nubank'), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(changes, [1]);
  });

  testWidgets('the last place adds a card', (tester) async {
    await show(tester, [card('Nubank')]);

    await tester.drag(find.text('Nubank'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar cartão'));

    expect(changes, [1]);
    expect(adds, 1);
  });

  testWidgets('a tap on a card at the side brings it to the front', (tester) async {
    await show(tester, [card('Nubank'), card('Itaú')]);

    // The second card peeks in on the right (from x 378 on a 400 wide screen).
    await tester.tapAt(const Offset(392, 100));
    await tester.pumpAndSettle();

    expect(changes, [1]);
  });

  testWidgets('one dot per place, the one in front longer', (tester) async {
    await show(tester, [card('Nubank'), card('Itaú')], index: 1);

    final dots = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer)).toList();
    expect(dots, hasLength(3));
    final widths = [for (final dot in dots) dot.constraints?.maxWidth];
    expect(widths, [8, 20, 8]);
  });

  testWidgets('with no cards, only "Adicionar cartão" and no dots', (tester) async {
    await show(tester, const []);

    expect(find.text('Adicionar cartão'), findsOneWidget);
    expect(find.byType(PageDots), findsNothing);
    await tester.tap(find.text('Adicionar cartão'));
    expect(adds, 1);
  });

  testWidgets('a screen reader hears which card it is', (tester) async {
    await show(tester, [card('Nubank'), card('Itaú')]);

    expect(
      find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == 'Cartão 1 de 2'),
      findsOneWidget,
    );
  });
}
