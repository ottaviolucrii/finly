import 'package:finly/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ThemeMode themeModeOf(WidgetTester tester) {
    return tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;
  }

  testWidgets('follows the phone by default', (tester) async {
    await tester.pumpWidget(const FinlyApp());

    expect(themeModeOf(tester), ThemeMode.system);
  });

  testWidgets('uses the theme mode it is given', (tester) async {
    await tester.pumpWidget(const FinlyApp(themeMode: ThemeMode.dark));

    expect(themeModeOf(tester), ThemeMode.dark);
  });

  testWidgets('changes the theme when the mode changes', (tester) async {
    await tester.pumpWidget(const FinlyApp(themeMode: ThemeMode.light));
    expect(themeModeOf(tester), ThemeMode.light);

    await tester.pumpWidget(const FinlyApp(themeMode: ThemeMode.dark));
    expect(themeModeOf(tester), ThemeMode.dark);
  });
}
