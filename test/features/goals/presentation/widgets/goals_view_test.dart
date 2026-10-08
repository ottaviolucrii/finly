import 'package:bloc_test/bloc_test.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/features/auth/domain/entities/tax_id_type.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/goals/domain/entities/goal.dart';
import 'package:finly/features/goals/domain/entities/goal_progress.dart';
import 'package:finly/features/goals/presentation/cubit/goals_cubit.dart';
import 'package:finly/features/goals/presentation/cubit/goals_state.dart';
import 'package:finly/features/goals/presentation/pages/goals_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGoalsCubit extends MockCubit<GoalsState> implements GoalsCubit {}

void main() {
  late MockGoalsCubit cubit;

  final now = DateTime(2026, 10, 7, 15);

  const personal = WorkspaceEntity(
    id: 'w1',
    ownerId: 'u1',
    name: 'Pessoal',
    taxId: '52998224725',
    taxIdType: TaxIdType.cpf,
    type: WorkspaceType.personal,
  );

  setUp(() {
    cubit = MockGoalsCubit();
    when(() => cubit.reload()).thenAnswer((_) async {});
  });

  GoalProgress progress(
    String name, {
    int balance = 125000,
    int target = 500000,
    DateTime? date,
    String account = 'Poupança',
  }) {
    return GoalProgress(
      goal: Goal(
        id: name,
        workspaceId: 'w1',
        accountId: 'a1',
        currency: 'BRL',
        name: name,
        targetCents: target,
        targetDate: date,
      ),
      accountName: account,
      balanceCents: balance,
    );
  }

  String money(int cents) => Money(cents, 'BRL').format();

  GoalProgress? opened;
  var opens = 0;
  bool? answer;

  Future<bool?> fakeOpen(BuildContext context, GoalProgress? editing) async {
    opens++;
    opened = editing;
    return answer;
  }

  setUp(() {
    opened = null;
    opens = 0;
    answer = null;
  });

  Future<void> show(WidgetTester tester, GoalsState state) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    whenListen(cubit, const Stream<GoalsState>.empty(), initialState: state);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<GoalsCubit>.value(
          value: cubit,
          child: GoalsView(workspace: personal, openForm: fakeOpen, clock: () => now),
        ),
      ),
    );
    await tester.pump();
  }

  GoalsState loaded(List<GoalProgress> items) => GoalsState(status: GoalsStatus.loaded, items: items);

  testWidgets('shows the title and the button for a new goal', (tester) async {
    await show(tester, loaded([progress('Reserva')]));

    expect(find.text('Metas'), findsOneWidget);
    expect(find.text('Nova meta'), findsOneWidget);
  });

  testWidgets('shows a card with the name, the percentage and the amounts', (tester) async {
    await show(tester, loaded([progress('Reserva de emergência')]));

    expect(find.text('Reserva de emergência'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('Poupança · BRL'), findsOneWidget);
    expect(find.text('${money(125000)} de ${money(500000)}'), findsOneWidget);
    expect(find.text('Faltam ${money(375000)}'), findsOneWidget);
  });

  testWidgets('a goal with a date says what to put aside each month', (tester) async {
    await show(tester, loaded([progress('Viagem', date: DateTime(2027, 1, 5))]));

    expect(
      find.text('Faltam ${money(375000)} · guarde ${money(125000)} por mês até 05/01/2027'),
      findsOneWidget,
    );
  });

  testWidgets('a goal reached says so', (tester) async {
    await show(tester, loaded([progress('Pronta', balance: 500000)]));

    expect(find.text('Meta alcançada'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('a goal past its date says it is overdue', (tester) async {
    await show(tester, loaded([progress('Atrasada', date: DateTime(2026, 6, 30))]));

    expect(find.textContaining('Prazo vencido em 30/06/2026'), findsOneWidget);
  });

  testWidgets('the progress bar follows the percentage', (tester) async {
    await show(tester, loaded([progress('Reserva')]));

    final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, 0.25);
  });

  testWidgets('says how many goals there are and how many were reached', (tester) async {
    await show(
      tester,
      loaded([progress('A'), progress('B', balance: 500000), progress('C', balance: 600000)]),
    );

    expect(find.text('3 metas · 2 alcançadas'), findsOneWidget);
  });

  testWidgets('tapping a card opens the form for that goal', (tester) async {
    final reserve = progress('Reserva');
    await show(tester, loaded([reserve]));

    await tester.tap(find.text('Reserva'));
    await tester.pump();

    expect(opens, 1);
    expect(opened, reserve);
  });

  testWidgets('the new goal button opens the form with no goal', (tester) async {
    await show(tester, loaded([progress('Reserva')]));

    await tester.tap(find.text('Nova meta'));
    await tester.pump();

    expect(opens, 1);
    expect(opened, isNull);
  });

  testWidgets('reads the goals again after something was saved', (tester) async {
    answer = true;
    await show(tester, loaded([progress('Reserva')]));

    await tester.tap(find.text('Nova meta'));
    await tester.pump();

    verify(() => cubit.reload()).called(1);
  });

  testWidgets('does not read again when the form was closed with nothing saved', (tester) async {
    answer = null;
    await show(tester, loaded([progress('Reserva')]));

    await tester.tap(find.text('Nova meta'));
    await tester.pump();

    verifyNever(() => cubit.reload());
  });

  testWidgets('with no goals it invites the person to create one', (tester) async {
    await show(tester, loaded(const []));

    expect(find.textContaining('ainda não tem metas'), findsOneWidget);
    expect(find.text('Nova meta'), findsOneWidget);
  });

  testWidgets('shows a spinner while the first goals load', (tester) async {
    await show(tester, const GoalsState());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('keeps the goals and shows a thin bar while it reads again', (tester) async {
    await show(
      tester,
      GoalsState(status: GoalsStatus.loading, items: [progress('Reserva')]),
    );

    expect(find.text('Reserva'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
  });

  testWidgets('a failure with nothing to show offers to try again', (tester) async {
    await show(
      tester,
      const GoalsState(status: GoalsStatus.failure, failure: NetworkFailure('network_error')),
    );

    expect(find.textContaining('conexão'), findsOneWidget);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();

    verify(() => cubit.reload()).called(1);
  });
}
