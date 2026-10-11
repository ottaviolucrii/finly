import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/dashboard/presentation/widgets/home/home_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> taps;

  setUp(() => taps = []);

  Future<void> show(WidgetTester tester, {bool busy = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: HomeShortcuts(
              onAdd: busy ? null : () => taps.add('add'),
              onTransfer: busy ? null : () => taps.add('transfer'),
              onPayInvoice: () => taps.add('invoice'),
              onForecast: () => taps.add('forecast'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the four shortcuts', (tester) async {
    await show(tester);

    for (final label in ['Lançar', 'Transferir', 'Pagar fatura', 'Previsão']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('each shortcut does its job', (tester) async {
    await show(tester);

    await tester.tap(find.text('Lançar'));
    await tester.tap(find.text('Transferir'));
    await tester.tap(find.text('Pagar fatura'));
    await tester.tap(find.text('Previsão'));

    expect(taps, ['add', 'transfer', 'invoice', 'forecast']);
  });

  testWidgets('while something is opening, adding and transferring wait', (tester) async {
    await show(tester, busy: true);

    await tester.tap(find.text('Lançar'));
    await tester.tap(find.text('Transferir'));

    expect(taps, isEmpty);
  });
}
