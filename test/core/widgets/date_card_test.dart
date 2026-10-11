import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/core/widgets/form_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: Scaffold(body: child)));
  }

  testWidgets('shows the date and opens the picker on a tap', (tester) async {
    var taps = 0;
    await show(tester, DateCard(value: '15/10/2026', onTap: () => taps++));

    expect(find.text('15/10/2026'), findsOneWidget);
    expect(find.text('Toque para mudar'), findsOneWidget);
    await tester.tap(find.text('15/10/2026'));
    expect(taps, 1);
  });

  testWidgets('an optional date has an ✕ to remove it', (tester) async {
    var clears = 0;
    await show(
      tester,
      DateCard(value: '15/10/2026', onTap: () {}, onClear: () => clears++, clearTooltip: 'Remover data final'),
    );

    await tester.tap(find.byTooltip('Remover data final'));
    expect(clears, 1);
  });

  testWidgets('a required date has no ✕', (tester) async {
    await show(tester, DateCard(value: 'Sem data final', onTap: () {}));

    expect(find.byIcon(Icons.close), findsNothing);
  });
}
