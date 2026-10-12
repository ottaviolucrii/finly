import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the brand, the title and the form', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const AuthScaffold(title: 'Entrar', subtitle: 'Que bom ver você de novo.', child: Text('formulário')),
      ),
    );

    expect(find.text('FINLY'), findsOneWidget);
    expect(find.text('INTELIGÊNCIA FINANCEIRA'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Que bom ver você de novo.'), findsOneWidget);
    expect(find.text('formulário'), findsOneWidget);
    expect(find.byTooltip('Voltar'), findsNothing);
  });

  testWidgets('opened from another screen, it has a back arrow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AuthScaffold(title: 'Criar conta', child: SizedBox())),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();

    expect(find.text('Criar conta'), findsNothing);
  });
}
