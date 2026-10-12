import 'package:finly/core/widgets/animated_splash.dart';
import 'package:finly/core/widgets/finly_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splashStep', () {
    test('is 0 before its window and 1 after it', () {
      expect(splashStep(0.1, 0.2, 0.5), 0);
      expect(splashStep(0.6, 0.2, 0.5), 1);
    });

    test('goes from 0 to 1 inside its window', () {
      final middle = splashStep(0.35, 0.2, 0.5);
      expect(middle, greaterThan(0));
      expect(middle, lessThan(1));
    });
  });

  testWidgets('plays once and says when it ends', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedSplash(duration: const Duration(milliseconds: 300), onFinished: () => finished++),
      ),
    );

    expect(finished, 0);
    await tester.pump(const Duration(milliseconds: 350));
    expect(finished, 1);
    expect(find.text('FINLY'), findsOneWidget);
  });

  testWidgets('with "remove animations" on, it ends at once', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: AnimatedSplash(onFinished: () => finished++),
        ),
      ),
    );
    await tester.pump();

    expect(finished, 1);
  });

  testWidgets('StartupSplash covers the app, then goes away and lets it be used', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StartupSplash(
          duration: const Duration(milliseconds: 200),
          child: Scaffold(body: Center(child: TextButton(onPressed: () => taps++, child: const Text('app')))),
        ),
      ),
    );

    expect(find.byType(AnimatedSplash), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.byType(AnimatedSplash), findsNothing);
    await tester.tap(find.text('app'));
    expect(taps, 1);
  });

  testWidgets('the logo paints at any point of the drawing', (tester) async {
    for (final value in [0.0, 0.3, 0.7, 1.0]) {
      await tester.pumpWidget(
        Center(
          child: CustomPaint(
            size: const Size(176, 190),
            painter: FinlyLogoPainter(upper: value, lower: value, goldLine: value, fill: value),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('while it shows, the app knows (the lock waits for it)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StartupSplash(duration: const Duration(milliseconds: 200), child: const SizedBox()),
      ),
    );

    expect(splashShowing.value, isTrue);
    await tester.pump(const Duration(milliseconds: 250));
    // The drawing ended, but it is still fading out: not done yet.
    expect(splashShowing.value, isTrue);
    await tester.pumpAndSettle();
    expect(splashShowing.value, isFalse);
  });

  testWidgets('the texts have a proper style (no yellow lines)', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(data: MediaQueryData(), child: AnimatedSplash(duration: Duration(milliseconds: 100))),
      ),
    );

    expect(find.byType(Material), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 150));
  });
}
