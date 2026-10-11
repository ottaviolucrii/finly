import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/core/widgets/workspace_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> show(WidgetTester tester, {required bool business}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          appBar: AppBar(
            title: WorkspaceTitle('Metas', isBusiness: business),
            backgroundColor: business ? AppColors.deepBlue : null,
            foregroundColor: business ? AppColors.white : null,
          ),
        ),
      ),
    );
  }

  testWidgets('in Empresa, the title has the tag, in the bar colors', (tester) async {
    await show(tester, business: true);

    expect(find.text('Metas'), findsOneWidget);
    final tag = tester.widget<Text>(find.text('Empresa'));
    expect(tag.style?.color, AppColors.white);
  });

  testWidgets('in Pessoal, only the title', (tester) async {
    await show(tester, business: false);

    expect(find.text('Metas'), findsOneWidget);
    expect(find.text('Empresa'), findsNothing);
  });

  testWidgets('a long title gives way to the tag', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          appBar: AppBar(
            title: const WorkspaceTitle('Histórico de alterações muito longo', isBusiness: true),
            backgroundColor: AppColors.deepBlue,
            foregroundColor: AppColors.white,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Empresa'), findsOneWidget);
  });
}
