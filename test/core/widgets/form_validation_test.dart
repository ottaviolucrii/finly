import 'package:finly/core/widgets/form_validation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late GlobalKey<FormState> key;

  Future<void> show(WidgetTester tester) async {
    key = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: key,
            onChanged: () => revalidateIfTried(key),
            child: Column(
              children: [
                TextFormField(validator: (v) => (v ?? '').trim().isEmpty ? 'Informe um nome.' : null),
                TextButton(onPressed: () => validateOnSave(key), child: const Text('Salvar')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('nothing in red while typing, before the first Save', (tester) async {
    await show(tester);

    await tester.enterText(find.byType(TextFormField), 'a');
    await tester.enterText(find.byType(TextFormField), '');
    await tester.pump();

    expect(find.text('Informe um nome.'), findsNothing);
  });

  testWidgets('Save shows what is missing', (tester) async {
    await show(tester);

    await tester.tap(find.text('Salvar'));
    await tester.pump();

    expect(find.text('Informe um nome.'), findsOneWidget);
  });

  testWidgets('after Save, the error goes away as soon as it is fixed', (tester) async {
    await show(tester);
    await tester.tap(find.text('Salvar'));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField), 'Itaú');
    await tester.pump();

    expect(find.text('Informe um nome.'), findsNothing);
  });

  testWidgets('a valid form saves', (tester) async {
    await show(tester);
    await tester.enterText(find.byType(TextFormField), 'Itaú');

    expect(validateOnSave(key), isTrue);
  });
}
