import 'package:finly/core/offline/offline_banner.dart';
import 'package:finly/core/offline/offline_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A screen with a state of its own, to prove the banner never rebuilds it.
class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => CounterState();
}

class CounterState extends State<Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tela')),
      body: Center(
        child: TextButton(
          onPressed: () => setState(() => taps++),
          child: Text('toques: $taps'),
        ),
      ),
    );
  }
}

void main() {
  late OfflineStatus status;
  final now = DateTime(2026, 10, 9, 18, 0);

  setUp(() => status = OfflineStatus());

  Future<void> show(WidgetTester tester, {Widget child = const Counter()}) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, navigator) => OfflineBanner(
          status: status,
          clock: () => now,
          child: navigator ?? const SizedBox.shrink(),
        ),
        home: child,
      ),
    );
  }

  group('cachedAtText', () {
    test('says "hoje" for the same day', () {
      expect(cachedAtText(DateTime(2026, 10, 9, 14, 32), now), 'hoje 14:32');
    });

    test('puts a zero before a single digit', () {
      expect(cachedAtText(DateTime(2026, 10, 9, 8, 5), now), 'hoje 08:05');
    });

    test('says the day and the month for another day', () {
      expect(cachedAtText(DateTime(2026, 10, 7, 14, 32), now), '07/10 14:32');
    });

    test('a day of another year is another day', () {
      expect(cachedAtText(DateTime(2025, 10, 9, 14, 32), now), '09/10 14:32');
    });
  });

  group('the banner', () {
    testWidgets('is not there while online', (tester) async {
      await show(tester);

      expect(find.textContaining('Sem conexão'), findsNothing);
      expect(find.textContaining('A internet voltou'), findsNothing);
      expect(find.text('Tela'), findsOneWidget);
    });

    testWidgets('says the app is offline', (tester) async {
      await show(tester);

      status.markOffline();
      await tester.pump();

      expect(find.text('Sem conexão ou conexão lenta.'), findsOneWidget);
    });

    testWidgets('says how old the data shown is', (tester) async {
      await show(tester);

      status.markServedFromCache(DateTime(2026, 10, 9, 14, 32));
      await tester.pump();

      expect(find.textContaining('mostrando dados salvos de hoje 14:32'), findsOneWidget);
    });

    testWidgets('says the data is from another day when it is', (tester) async {
      await show(tester);

      status.markServedFromCache(DateTime(2026, 10, 7, 9, 5));
      await tester.pump();

      expect(find.textContaining('de 07/10 09:05'), findsOneWidget);
    });

    testWidgets('says the internet is back, and offers to refresh', (tester) async {
      await show(tester);
      status.markOffline();
      await tester.pump();

      status.markOnline();
      await tester.pump();

      expect(find.text('A internet voltou.'), findsOneWidget);
      expect(find.text('Atualizar'), findsOneWidget);
      expect(find.textContaining('Sem conexão'), findsNothing);
    });

    testWidgets('refreshing asks the app to be built again and hides the bar', (tester) async {
      await show(tester);
      status.markOffline();
      status.markOnline();
      await tester.pump();

      await tester.tap(find.text('Atualizar'));
      await tester.pump();

      expect(status.refreshEpoch, 1);
      expect(find.text('A internet voltou.'), findsNothing);
    });

    testWidgets('goes away when the data is live again and the person refreshed', (tester) async {
      await show(tester);
      status.markOffline();
      await tester.pump();
      expect(find.textContaining('Sem conexão'), findsOneWidget);

      status.markOnline();
      status.refresh();
      await tester.pump();

      expect(find.textContaining('Sem conexão'), findsNothing);
      expect(find.text('Atualizar'), findsNothing);
    });
  });

  group('the screen below the banner', () {
    testWidgets('is not built again when the banner appears and goes (nothing is lost)', (tester) async {
      await show(tester);
      await tester.tap(find.text('toques: 0'));
      await tester.pump();
      await tester.tap(find.text('toques: 1'));
      await tester.pump();
      expect(find.text('toques: 2'), findsOneWidget);
      final state = tester.state<CounterState>(find.byType(Counter));

      status.markOffline();
      await tester.pump();
      expect(find.text('toques: 2'), findsOneWidget);
      expect(tester.state<CounterState>(find.byType(Counter)), same(state));

      status.markOnline();
      await tester.pump();
      expect(find.text('toques: 2'), findsOneWidget);
      expect(tester.state<CounterState>(find.byType(Counter)), same(state));

      await tester.tap(find.text('Atualizar'));
      await tester.pump();
      expect(find.text('toques: 2'), findsOneWidget);
      expect(tester.state<CounterState>(find.byType(Counter)), same(state));
    });

    testWidgets('stays on the page the person was on', (tester) async {
      await show(tester);
      Navigator.of(tester.element(find.byType(Counter))).push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('segunda página'))),
      );
      await tester.pumpAndSettle();

      status.markOffline();
      await tester.pump();

      expect(find.text('segunda página'), findsOneWidget);
    });

    testWidgets('is pushed down by the banner, and the page does not leave the space of the status bar empty',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await show(tester);
      final titleBefore = tester.getTopLeft(find.text('Tela')).dy;

      status.markOffline();
      await tester.pump();
      final titleAfter = tester.getTopLeft(find.text('Tela')).dy;

      // Pushed down by about the height of the bar, and no more than that.
      expect(titleAfter, greaterThan(titleBefore));
      expect(titleAfter - titleBefore, lessThan(60));
    });
  });
}
