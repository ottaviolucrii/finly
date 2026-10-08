import 'package:bloc_test/bloc_test.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/audit/domain/audit_filter.dart';
import 'package:finly/features/audit/domain/entities/audit_item.dart';
import 'package:finly/features/audit/presentation/cubit/audit_cubit.dart';
import 'package:finly/features/audit/presentation/cubit/audit_state.dart';
import 'package:finly/features/audit/presentation/pages/audit_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuditCubit extends MockCubit<AuditState> implements AuditCubit {}

void main() {
  late MockAuditCubit cubit;

  final now = DateTime(2026, 10, 7, 15);

  setUpAll(() => registerFallbackValue(AuditFilter.all));

  setUp(() {
    cubit = MockAuditCubit();
    when(() => cubit.refresh()).thenAnswer((_) async {});
    when(() => cubit.loadMore()).thenAnswer((_) async {});
    when(() => cubit.setFilter(any())).thenAnswer((_) async {});
  });

  AuditItem item(
    String id,
    String title, {
    DateTime? at,
    AuditKind kind = AuditKind.created,
    String summary = '',
    List<AuditChange> changes = const [],
  }) {
    return AuditItem(
      id: id,
      tableName: 'transactions',
      kind: kind,
      title: title,
      summary: summary,
      changes: changes,
      occurredAt: at ?? DateTime(2026, 10, 7, 10, 30),
    );
  }

  Future<void> show(WidgetTester tester, AuditState state) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    whenListen(cubit, const Stream<AuditState>.empty(), initialState: state);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuditCubit>.value(
          value: cubit,
          child: AuditHistoryView(clock: () => now),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the title and the filters', (tester) async {
    await show(tester, const AuditState(status: AuditStatus.loaded));

    expect(find.text('Histórico de alterações'), findsOneWidget);
    for (final label in ['Tudo', 'Transações', 'Contas e cartões', 'Categorias', 'Orçamentos', 'Recorrências']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('tapping a filter asks the cubit for it', (tester) async {
    await show(tester, const AuditState(status: AuditStatus.loaded));

    await tester.tap(find.text('Orçamentos'));
    await tester.pump();

    verify(() => cubit.setFilter(AuditFilter.budgets)).called(1);
  });

  testWidgets('the filter on screen is the selected chip', (tester) async {
    await show(tester, const AuditState(status: AuditStatus.loaded, filter: AuditFilter.accounts));

    final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Contas e cartões'));
    expect(chip.selected, isTrue);
    final other = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Tudo'));
    expect(other.selected, isFalse);
  });

  testWidgets('shows the lines with the time and the summary', (tester) async {
    await show(
      tester,
      AuditState(
        status: AuditStatus.loaded,
        items: [item('1', 'Saída criada: Mercado', summary: 'Saída · R\$ 120,00 · 07/10/2026')],
      ),
    );

    expect(find.text('Saída criada: Mercado'), findsOneWidget);
    expect(find.text('10:30 · Saída · R\$ 120,00 · 07/10/2026'), findsOneWidget);
  });

  testWidgets('groups the lines by day with Hoje, Ontem and the date', (tester) async {
    await show(
      tester,
      AuditState(
        status: AuditStatus.loaded,
        items: [
          item('1', 'A', at: DateTime(2026, 10, 7, 9)),
          item('2', 'B', at: DateTime(2026, 10, 7, 8)),
          item('3', 'C', at: DateTime(2026, 10, 6, 20)),
          item('4', 'D', at: DateTime(2026, 10, 3, 12)),
        ],
      ),
    );

    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text('Ontem'), findsOneWidget);
    expect(find.text('03/10/2026'), findsOneWidget);
  });

  testWidgets('an edit opens to show what changed', (tester) async {
    await show(
      tester,
      AuditState(
        status: AuditStatus.loaded,
        items: [
          item(
            '1',
            'Saída alterada: Mercado',
            kind: AuditKind.edited,
            changes: const [
              AuditChange(label: 'Valor', before: 'R\$ 100,00', after: 'R\$ 120,00'),
              AuditChange(label: 'Conta', before: 'C6', after: 'XP'),
            ],
          ),
        ],
      ),
    );

    expect(find.textContaining('Valor:', findRichText: true), findsNothing);

    await tester.tap(find.text('Saída alterada: Mercado'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Valor:', findRichText: true), findsOneWidget);
    expect(find.textContaining('R\$ 120,00', findRichText: true), findsOneWidget);
    expect(find.textContaining('Conta:', findRichText: true), findsOneWidget);
  });

  testWidgets('a line without changes is not expandable', (tester) async {
    await show(
      tester,
      AuditState(status: AuditStatus.loaded, items: [item('1', 'Conta criada: C6')]),
    );

    expect(find.byType(ExpansionTile), findsNothing);
  });

  testWidgets('has an icon for each kind of change', (tester) async {
    await show(
      tester,
      AuditState(
        status: AuditStatus.loaded,
        items: [
          item('1', 'criada', kind: AuditKind.created),
          item('2', 'enviada', kind: AuditKind.trashed),
          item('3', 'restaurada', kind: AuditKind.restored),
          item('4', 'excluida', kind: AuditKind.deleted),
        ],
      ),
    );

    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.restore_from_trash_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
  });

  testWidgets('offers more when there is more, and asks for it', (tester) async {
    await show(
      tester,
      AuditState(status: AuditStatus.loaded, items: [item('1', 'A')], hasMore: true),
    );

    await tester.tap(find.text('Carregar mais'));
    await tester.pump();

    verify(() => cubit.loadMore()).called(1);
  });

  testWidgets('shows a spinner instead of the button while loading more', (tester) async {
    await show(
      tester,
      AuditState(
        status: AuditStatus.loaded,
        items: [item('1', 'A')],
        hasMore: true,
        loadingMore: true,
      ),
    );

    expect(find.text('Carregar mais'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('has no button when everything is shown', (tester) async {
    await show(tester, AuditState(status: AuditStatus.loaded, items: [item('1', 'A')]));

    expect(find.text('Carregar mais'), findsNothing);
  });

  testWidgets('says when nothing was recorded', (tester) async {
    await show(tester, const AuditState(status: AuditStatus.loaded));

    expect(find.text('Nenhuma alteração registrada.'), findsOneWidget);
  });

  testWidgets('a failure with nothing to show offers to try again', (tester) async {
    await show(
      tester,
      const AuditState(
        status: AuditStatus.failure,
        failure: NetworkFailure('network_error'),
      ),
    );

    expect(find.textContaining('conexão'), findsOneWidget);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();

    verify(() => cubit.refresh()).called(1);
  });

  testWidgets('shows a spinner while the first page loads', (tester) async {
    await show(tester, const AuditState());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('keeps the list and shows a thin bar while it refreshes', (tester) async {
    await show(
      tester,
      AuditState(status: AuditStatus.loading, items: [item('1', 'Conta criada: C6')]),
    );

    expect(find.text('Conta criada: C6'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
