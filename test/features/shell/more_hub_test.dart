import 'package:finly/core/theme/app_theme.dart';
import 'package:finly/features/auth/domain/entities/tax_id_type.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/shell/presentation/more_hub.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const personal = WorkspaceEntity(
    id: 'w1',
    ownerId: 'u1',
    name: 'Ottávio',
    taxId: '00000000000',
    taxIdType: TaxIdType.cpf,
    type: WorkspaceType.personal,
  );
  const business = WorkspaceEntity(
    id: 'w2',
    ownerId: 'u1',
    name: 'Ottávio ME',
    taxId: '00000000000000',
    taxIdType: TaxIdType.cnpj,
    type: WorkspaceType.business,
  );

  UserEntity user({List<WorkspaceEntity> workspaces = const [personal, business]}) {
    return UserEntity(
      id: 'u1',
      fullName: 'Ottávio Lucri',
      email: 'ottavio@example.com',
      workspaces: workspaces,
      activeWorkspaceId: 'w1',
    );
  }

  late List<MoreDestination> opened;
  late List<WorkspaceEntity> switchedTo;
  late List<WorkspaceType> added;
  late int signOuts;

  setUp(() {
    opened = [];
    switchedTo = [];
    added = [];
    signOuts = 0;
  });

  Future<void> show(
    WidgetTester tester, {
    UserEntity? who,
    bool switching = false,
    bool signingOut = false,
  }) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: MoreHub(
            user: who ?? user(),
            switching: switching,
            signingOut: signingOut,
            onOpen: opened.add,
            onSwitchTo: switchedTo.add,
            onAddWorkspace: added.add,
            onSignOut: () => signOuts++,
          ),
        ),
      ),
    );
  }

  group('initialOf', () {
    test('is the first letter, in capitals', () {
      expect(initialOf('ottávio'), 'O');
      expect(initialOf('  Ana Paula'), 'A');
    });

    test('is a question mark for an empty name', () {
      expect(initialOf(''), '?');
      expect(initialOf('   '), '?');
    });
  });

  testWidgets('shows who is signed in', (tester) async {
    await show(tester);

    expect(find.text('SUA CONTA'), findsOneWidget);
    expect(find.text('Mais'), findsOneWidget);
    expect(find.text('Ottávio Lucri'), findsOneWidget);
    expect(find.text('ottavio@example.com'), findsOneWidget);
    expect(find.text('O'), findsOneWidget);
  });

  testWidgets('lists the rest of the app in groups', (tester) async {
    await show(tester);

    for (final label in ['DINHEIRO', 'ANÁLISES', 'CONTA E PRIVACIDADE']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final title in ['Contas', 'Cartões', 'Categorias', 'Relatórios', 'Histórico de alterações', 'Configurações', 'Sair']) {
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('each row opens its place', (tester) async {
    await show(tester);

    await tester.tap(find.text('Contas'));
    await tester.tap(find.text('Cartões'));
    await tester.tap(find.text('Categorias'));
    await tester.tap(find.text('Relatórios'));
    await tester.tap(find.text('Histórico de alterações'));
    await tester.tap(find.text('Configurações'));

    expect(opened, [
      MoreDestination.accounts,
      MoreDestination.cards,
      MoreDestination.categories,
      MoreDestination.reports,
      MoreDestination.history,
      MoreDestination.settings,
    ]);
  });

  testWidgets('shows both workspaces, the active one marked', (tester) async {
    await show(tester);

    expect(find.text('Pessoal (CPF)'), findsOneWidget);
    expect(find.text('Empresa (CNPJ)'), findsOneWidget);

    final active = semanticsLabelled(tester, 'Pessoal (CPF)');
    expect(active.button, isTrue);
    expect(active.selected, isTrue);

    final other = semanticsLabelled(tester, 'Empresa (CNPJ)');
    expect(other.selected, isFalse);
    expect(other.onTap, isNotNull);
  });

  testWidgets('tapping the other workspace asks to switch to it', (tester) async {
    await show(tester);

    await tester.tap(find.text('Empresa (CNPJ)'));

    expect(switchedTo, [business]);
  });

  testWidgets('tapping the active workspace does nothing', (tester) async {
    await show(tester);

    await tester.tap(find.text('Pessoal (CPF)'));

    expect(switchedTo, isEmpty);
  });

  testWidgets('the switch waits while a switch is going on', (tester) async {
    await show(tester, switching: true);

    await tester.tap(find.text('Empresa (CNPJ)'));

    expect(switchedTo, isEmpty);
  });

  testWidgets('with one workspace, offers to add the other', (tester) async {
    await show(tester, who: user(workspaces: const [personal]));

    expect(find.text('Empresa (CNPJ)'), findsNothing);
    await tester.tap(find.text('Adicionar a empresa (CNPJ)'));

    expect(added, [WorkspaceType.business]);
  });

  testWidgets('with only the company, offers to add the personal one', (tester) async {
    await show(tester, who: UserEntity(id: 'u1', fullName: 'Ottávio', email: 'o@example.com', workspaces: const [business], activeWorkspaceId: 'w2'));

    await tester.tap(find.text('Adicionar o pessoal (CPF)'));

    expect(added, [WorkspaceType.personal]);
  });

  testWidgets('signs out', (tester) async {
    await show(tester);

    await tester.tap(find.text('Sair'));

    expect(signOuts, 1);
  });

  testWidgets('cannot sign out twice while signing out', (tester) async {
    await show(tester, signingOut: true);

    await tester.tap(find.text('Sair'));

    expect(signOuts, 0);
  });
}

/// The properties a [Semantics] widget gives to screen readers, found by its label.
SemanticsProperties semanticsLabelled(WidgetTester tester, String label) {
  return tester
      .widget<Semantics>(
        find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label),
      )
      .properties;
}
