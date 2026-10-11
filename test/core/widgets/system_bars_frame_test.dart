import 'package:finly/core/widgets/system_bars_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MediaQueryData inside;

  Future<void> show(WidgetTester tester, {double bar = 0, double keyboard = 0}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 800),
          padding: EdgeInsets.only(top: 24, bottom: bar),
          viewPadding: EdgeInsets.only(top: 24, bottom: bar),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: SystemBarsFrame(
          color: Colors.white,
          child: Builder(
            builder: (context) {
              inside = MediaQuery.of(context);
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
  }

  testWidgets('the app stops above the navigation bar', (tester) async {
    await show(tester, bar: 48);

    final padding = tester.widget<Padding>(find.byType(Padding).first);
    expect(padding.padding, const EdgeInsets.only(bottom: 48));
    expect(tester.getSize(find.byType(SizedBox)).height, 800 - 48);
  });

  testWidgets('inside, the bottom padding is zero and the top is kept', (tester) async {
    await show(tester, bar: 48);

    expect(inside.padding.bottom, 0);
    expect(inside.viewPadding.bottom, 0);
    expect(inside.padding.top, 24);
  });

  testWidgets('the keyboard is measured from the bottom of the app', (tester) async {
    await show(tester, bar: 48, keyboard: 300);

    expect(inside.viewInsets.bottom, 252);
  });

  testWidgets('a keyboard shorter than the bar counts as none', (tester) async {
    await show(tester, bar: 48, keyboard: 20);

    expect(inside.viewInsets.bottom, 0);
  });

  testWidgets('without a navigation bar nothing changes', (tester) async {
    await show(tester, keyboard: 300);

    expect(find.byType(ColoredBox), findsNothing);
    expect(inside.viewInsets.bottom, 300);
  });
}
