import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/cards/presentation/widgets/card_days_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dayOfMonth', () {
    test('1 to 31 are days', () {
      expect(dayOfMonth('1'), 1);
      expect(dayOfMonth(' 31 '), 31);
    });

    test('anything else is not', () {
      expect(dayOfMonth('0'), isNull);
      expect(dayOfMonth('32'), isNull);
      expect(dayOfMonth(''), isNull);
      expect(dayOfMonth('a'), isNull);
    });
  });

  testWidgets('both days are checked', (tester) async {
    final closing = TextEditingController(text: '40');
    final due = TextEditingController(text: '17');
    addTearDown(closing.dispose);
    addTearDown(due.dispose);
    final form = GlobalKey<FormState>();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Form(key: form, child: CardDaysFields(closing: closing, due: due, enabled: true)),
        ),
      ),
    );

    expect(find.text('Fecha no dia'), findsOneWidget);
    expect(find.text('Vence no dia'), findsOneWidget);
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('De 1 a 31.'), findsOneWidget);
  });
}
