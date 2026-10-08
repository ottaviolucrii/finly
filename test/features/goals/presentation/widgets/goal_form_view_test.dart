import 'package:bloc_test/bloc_test.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/goals/domain/entities/goal.dart';
import 'package:finly/features/goals/domain/entities/goal_progress.dart';
import 'package:finly/features/goals/domain/usecases/save_goal_use_case.dart';
import 'package:finly/features/goals/presentation/cubit/goal_form_cubit.dart';
import 'package:finly/features/goals/presentation/cubit/goal_form_state.dart';
import 'package:finly/features/goals/presentation/pages/goal_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGoalFormCubit extends MockCubit<GoalFormState> implements GoalFormCubit {}

void main() {
  late MockGoalFormCubit cubit;

  AccountEntity account(String id, String name, {String currency = 'BRL'}) {
    return AccountEntity(
      id: id,
      workspaceId: 'w1',
      name: name,
      type: AccountType.savings,
      currency: currency,
      openingBalanceCents: 0,
      postedBalanceCents: 0,
      projectedBalanceCents: 0,
    );
  }

  final poupanca = account('a1', 'Poupança');
  final nubank = account('a2', 'Nubank');
  final dolar = account('a3', 'Dólar', currency: 'USD');

  final editing = GoalProgress(
    goal: Goal(
      id: 'g1',
      workspaceId: 'w1',
      accountId: 'a1',
      currency: 'BRL',
      name: 'Reserva',
      targetCents: 500000,
      targetDate: DateTime(2027, 6, 30),
    ),
    accountName: 'Poupança',
    balanceCents: 125000,
  );

  setUpAll(() => registerFallbackValue(
        const SaveGoalParams(
          workspaceId: 'w1',
          accountId: 'a1',
          currency: 'BRL',
          name: 'x',
          targetCents: 1,
        ),
      ));

  setUp(() {
    cubit = MockGoalFormCubit();
    when(() => cubit.save(any())).thenAnswer((_) async {});
    when(() => cubit.archive(any())).thenAnswer((_) async {});
    when(() => cubit.load(any())).thenAnswer((_) async {});
  });

  GoalFormState ready([List<AccountEntity>? accounts]) {
    return GoalFormState(
      status: GoalFormStatus.ready,
      accounts: accounts ?? [poupanca, nubank, dolar],
    );
  }

  Future<void> show(
    WidgetTester tester,
    GoalFormState state, {
    GoalProgress? goal,
    Stream<GoalFormState>? later,
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    whenListen(cubit, later ?? const Stream<GoalFormState>.empty(), initialState: state);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<GoalFormCubit>.value(
          value: cubit,
          child: GoalFormView(workspaceId: 'w1', editing: goal),
        ),
      ),
    );
    await tester.pump();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  SaveGoalParams savedParams() {
    return verify(() => cubit.save(captureAny())).captured.single as SaveGoalParams;
  }

  group('a new goal', () {
    testWidgets('shows the form with the accounts as choices', (tester) async {
      await show(tester, ready());

      expect(find.text('Nova meta'), findsOneWidget);
      expect(field('Nome da meta'), findsOneWidget);
      expect(field('Valor da meta'), findsOneWidget);
      expect(find.text('Poupança (BRL)'), findsOneWidget);
      expect(find.text('Nubank (BRL)'), findsOneWidget);
      expect(find.text('Dólar (USD)'), findsOneWidget);
      expect(find.text('Sem prazo'), findsOneWidget);
      expect(find.text('Criar meta'), findsOneWidget);
      expect(find.text('Arquivar meta'), findsNothing);
    });

    testWidgets('saves the goal with the account and its currency', (tester) async {
      await show(tester, ready());

      await tester.enterText(field('Nome da meta'), '  Reserva  ');
      await tester.tap(find.text('Nubank (BRL)'));
      await tester.pump();
      await tester.enterText(field('Valor da meta'), '5000,00');
      await tester.tap(find.text('Criar meta'));
      await tester.pump();

      final params = savedParams();
      expect(params.id, isNull);
      expect(params.workspaceId, 'w1');
      expect(params.accountId, 'a2');
      expect(params.currency, 'BRL');
      expect(params.name.trim(), 'Reserva');
      expect(params.targetCents, 500000);
      expect(params.targetDate, isNull);
    });

    testWidgets('the currency is the one of the account chosen', (tester) async {
      await show(tester, ready());

      await tester.enterText(field('Nome da meta'), 'Viagem');
      await tester.tap(find.text('Dólar (USD)'));
      await tester.pump();
      await tester.enterText(field('Valor da meta'), '2000,00');
      await tester.tap(find.text('Criar meta'));
      await tester.pump();

      final params = savedParams();
      expect(params.currency, 'USD');
      expect(params.targetCents, 200000);
    });

    testWidgets('without a name it shows an error and saves nothing', (tester) async {
      await show(tester, ready());

      await tester.tap(find.text('Poupança (BRL)'));
      await tester.pump();
      await tester.enterText(field('Valor da meta'), '100,00');
      await tester.tap(find.text('Criar meta'));
      await tester.pump();

      expect(find.text('Informe um nome para a meta.'), findsOneWidget);
      verifyNever(() => cubit.save(any()));
    });

    testWidgets('a target of zero shows an error and saves nothing', (tester) async {
      await show(tester, ready());

      await tester.enterText(field('Nome da meta'), 'Reserva');
      await tester.tap(find.text('Poupança (BRL)'));
      await tester.pump();
      await tester.enterText(field('Valor da meta'), '0');
      await tester.tap(find.text('Criar meta'));
      await tester.pump();

      expect(find.textContaining('maior que zero'), findsOneWidget);
      verifyNever(() => cubit.save(any()));
    });

    testWidgets('without an account chosen it asks for one and saves nothing', (tester) async {
      await show(tester, ready());

      await tester.enterText(field('Nome da meta'), 'Reserva');
      await tester.enterText(field('Valor da meta'), '100,00');
      await tester.tap(find.text('Criar meta'));
      await tester.pump();

      expect(find.text('Escolha uma conta.'), findsOneWidget);
      verifyNever(() => cubit.save(any()));
    });

    testWidgets('with no accounts it says to create one', (tester) async {
      await show(tester, ready(const []));

      expect(find.textContaining('Crie uma conta'), findsOneWidget);
    });

    testWidgets('shows a spinner while the accounts load', (tester) async {
      await show(tester, const GoalFormState());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(field('Nome da meta'), findsNothing);
    });

    testWidgets('offers to try again when the accounts could not be read', (tester) async {
      await show(
        tester,
        const GoalFormState(
          status: GoalFormStatus.loadFailed,
          loadFailure: NetworkFailure('network_error'),
        ),
      );

      expect(find.textContaining('conexão'), findsOneWidget);

      await tester.tap(find.text('Tentar de novo'));
      await tester.pump();

      verify(() => cubit.load('w1')).called(1);
    });

    testWidgets('disables the button and shows a spinner while saving', (tester) async {
      await show(tester, GoalFormState(status: GoalFormStatus.saving, accounts: [poupanca]));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Criar meta'), findsNothing);
    });

    testWidgets('says why a save was refused', (tester) async {
      await show(
        tester,
        ready(),
        later: Stream.value(
          GoalFormState(
            status: GoalFormStatus.ready,
            accounts: [poupanca],
            saveFailure: const ConflictFailure('already_exists'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Já existe uma meta com esse nome.'), findsOneWidget);
    });
  });

  group('changing a goal', () {
    testWidgets('starts with what the goal has', (tester) async {
      await show(tester, ready(), goal: editing);

      expect(find.text('Editar meta'), findsOneWidget);
      expect(tester.widget<TextFormField>(field('Nome da meta')).controller!.text, 'Reserva');
      expect(
        tester.widget<TextFormField>(field('Valor da meta')).controller!.text,
        Money(500000, 'BRL').format(withSymbol: false),
      );
      expect(find.text('30/06/2027'), findsOneWidget);
      expect(find.text('Salvar alterações'), findsOneWidget);
    });

    testWidgets('only the accounts in the currency of the goal can be chosen', (tester) async {
      await show(tester, ready(), goal: editing);

      expect(find.text('Poupança (BRL)'), findsOneWidget);
      expect(find.text('Nubank (BRL)'), findsOneWidget);
      expect(find.text('Dólar (USD)'), findsNothing);
    });

    testWidgets('the account of the goal is already chosen', (tester) async {
      await show(tester, ready(), goal: editing);

      final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Poupança (BRL)'));
      expect(chip.selected, isTrue);
    });

    testWidgets('saves with the id of the goal and keeps its date', (tester) async {
      await show(tester, ready(), goal: editing);

      await tester.enterText(field('Valor da meta'), '7000,00');
      await tester.tap(find.text('Salvar alterações'));
      await tester.pump();

      final params = savedParams();
      expect(params.id, 'g1');
      expect(params.accountId, 'a1');
      expect(params.currency, 'BRL');
      expect(params.targetCents, 700000);
      expect(params.targetDate, DateTime(2027, 6, 30));
    });

    testWidgets('the date can be taken off', (tester) async {
      await show(tester, ready(), goal: editing);

      await tester.tap(find.byTooltip('Tirar o prazo'));
      await tester.pump();

      expect(find.text('Sem prazo'), findsOneWidget);

      await tester.tap(find.text('Salvar alterações'));
      await tester.pump();

      expect(savedParams().targetDate, isNull);
    });

    testWidgets('archiving asks first and then archives', (tester) async {
      await show(tester, ready(), goal: editing);

      await tester.tap(find.text('Arquivar meta'));
      await tester.pumpAndSettle();

      expect(find.text('Arquivar meta?'), findsOneWidget);
      verifyNever(() => cubit.archive(any()));

      await tester.tap(find.text('Arquivar'));
      await tester.pumpAndSettle();

      verify(() => cubit.archive('g1')).called(1);
    });

    testWidgets('cancelling the archive does nothing', (tester) async {
      await show(tester, ready(), goal: editing);

      await tester.tap(find.text('Arquivar meta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      verifyNever(() => cubit.archive(any()));
    });
  });

  group('closing the form', () {
    Future<bool?> openAndGetResult(WidgetTester tester, GoalFormStatus closing) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      whenListen(
        cubit,
        Stream.fromFuture(
          Future<GoalFormState>.delayed(
            const Duration(milliseconds: 10),
            () => GoalFormState(status: closing, accounts: [poupanca]),
          ),
        ),
        initialState: ready(),
      );

      bool? result = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => BlocProvider<GoalFormCubit>.value(
                        value: cubit,
                        child: const GoalFormView(workspaceId: 'w1'),
                      ),
                    ),
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('a saved goal closes the form with true', (tester) async {
      final result = await openAndGetResult(tester, GoalFormStatus.saved);

      expect(result, isTrue);
      expect(find.byType(GoalFormView), findsNothing);
    });

    testWidgets('an archived goal closes the form with true', (tester) async {
      final result = await openAndGetResult(tester, GoalFormStatus.archived);

      expect(result, isTrue);
      expect(find.byType(GoalFormView), findsNothing);
    });
  });
}
