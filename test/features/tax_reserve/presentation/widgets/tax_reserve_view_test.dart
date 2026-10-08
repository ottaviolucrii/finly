import 'package:bloc_test/bloc_test.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/features/tax_reserve/domain/entities/tax_reserve_data.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_reserve_cubit.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_reserve_state.dart';
import 'package:finly/features/tax_reserve/presentation/pages/tax_reserve_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockTaxReserveCubit extends MockCubit<TaxReserveState> implements TaxReserveCubit {}

void main() {
  late MockTaxReserveCubit cubit;

  final october = DateTime(2026, 10);

  const data = TaxReserveData(
    percentBps: 650,
    currency: 'BRL',
    incomeCents: 500000,
    taxCents: 12000,
  );

  setUp(() {
    cubit = MockTaxReserveCubit();
    when(() => cubit.savePercent(any())).thenAnswer((_) async {});
    when(() => cubit.previousMonth()).thenAnswer((_) async {});
    when(() => cubit.nextMonth()).thenAnswer((_) async {});
    when(() => cubit.reload()).thenAnswer((_) async {});
  });

  TaxReserveState loaded({
    TaxReserveData? withData = data,
    DateTime? month,
    TaxReserveStatus status = TaxReserveStatus.loaded,
    Failure? failure,
  }) {
    return TaxReserveState(
      status: status,
      month: month ?? october,
      currentMonth: october,
      data: withData,
      failure: failure,
    );
  }

  Future<void> show(
    WidgetTester tester,
    TaxReserveState state, {
    Stream<TaxReserveState>? later,
  }) async {
    whenListen(cubit, later ?? const Stream<TaxReserveState>.empty(), initialState: state);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<TaxReserveCubit>.value(
          value: cubit,
          child: const TaxReserveView(),
        ),
      ),
    );
    await tester.pump();
  }

  String money(int cents) => Money(cents, 'BRL').format();

  test('taxReserveMonthTitle writes the month in full', () {
    expect(taxReserveMonthTitle(DateTime(2026, 10)), 'Outubro de 2026');
    expect(taxReserveMonthTitle(DateTime(2027, 3)), 'Março de 2027');
  });

  testWidgets('shows the month, the percentage and the numbers', (tester) async {
    await show(tester, loaded());

    expect(find.text('Reserva para impostos'), findsOneWidget);
    expect(find.text('Outubro de 2026'), findsOneWidget);
    expect(find.text('Reserva de 6,5%'), findsOneWidget);
    expect(find.text('Entradas do mês'), findsOneWidget);
    expect(find.text(money(500000)), findsOneWidget);
    expect(find.text('A reservar'), findsOneWidget);
    expect(find.text(money(32500)), findsOneWidget);
    expect(find.text('Impostos do mês'), findsOneWidget);
    expect(find.text(money(12000)), findsOneWidget);
    expect(find.text('Reserva disponível'), findsOneWidget);
    expect(find.text(money(20500)), findsOneWidget);
  });

  testWidgets('names the currency of the workspace', (tester) async {
    await show(tester, loaded());

    expect(find.textContaining('em BRL'), findsOneWidget);
  });

  testWidgets('taxes above the reserve are shown in their own line', (tester) async {
    await show(
      tester,
      loaded(
        withData: const TaxReserveData(
          percentBps: 650,
          currency: 'BRL',
          incomeCents: 500000,
          taxCents: 40000,
        ),
      ),
    );

    expect(find.text('Impostos acima da reserva'), findsOneWidget);
    expect(find.text(money(7500)), findsOneWidget);
    expect(find.text('Reserva disponível'), findsNothing);
  });

  testWidgets('without a percentage it asks the person to choose one', (tester) async {
    await show(
      tester,
      loaded(
        withData: const TaxReserveData(
          percentBps: 0,
          currency: 'BRL',
          incomeCents: 500000,
          taxCents: 0,
        ),
      ),
    );

    expect(find.text('Defina quanto reservar'), findsOneWidget);
    expect(find.text('Definir porcentagem'), findsOneWidget);
    expect(find.text('A reservar'), findsNothing);
  });

  testWidgets('choosing a percentage saves it in basis points', (tester) async {
    await show(tester, loaded());

    await tester.tap(find.text('Alterar'));
    await tester.pumpAndSettle();
    expect(find.text('Quanto reservar?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '8,25');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    verify(() => cubit.savePercent(825)).called(1);
  });

  testWidgets('the dialog starts with the current percentage', (tester) async {
    await show(tester, loaded());

    await tester.tap(find.text('Alterar'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '6,5');
  });

  testWidgets('a value that is not a percentage shows an error and saves nothing', (tester) async {
    await show(tester, loaded());

    await tester.tap(find.text('Alterar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '150');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('de 0 a 100'), findsOneWidget);
    expect(find.text('Quanto reservar?'), findsOneWidget);
    verifyNever(() => cubit.savePercent(any()));
  });

  testWidgets('cancelling saves nothing', (tester) async {
    await show(tester, loaded());

    await tester.tap(find.text('Alterar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    verifyNever(() => cubit.savePercent(any()));
    expect(find.text('Quanto reservar?'), findsNothing);
  });

  testWidgets('choosing the same percentage again saves nothing', (tester) async {
    await show(tester, loaded());

    await tester.tap(find.text('Alterar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    verifyNever(() => cubit.savePercent(any()));
  });

  testWidgets('the arrows change the month, and the next one is off on the current month', (tester) async {
    await show(tester, loaded());

    await tester.tap(find.byTooltip('Mês anterior'));
    await tester.pump();
    verify(() => cubit.previousMonth()).called(1);

    final next = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right));
    expect(next.onPressed, isNull);
  });

  testWidgets('the next month is on when an older month is shown', (tester) async {
    await show(tester, loaded(month: DateTime(2026, 9)));

    await tester.tap(find.byTooltip('Próximo mês'));
    await tester.pump();

    verify(() => cubit.nextMonth()).called(1);
  });

  testWidgets('a failure with nothing to show offers to try again', (tester) async {
    await show(
      tester,
      loaded(
        withData: null,
        status: TaxReserveStatus.failure,
        failure: const NetworkFailure('network_error'),
      ),
    );

    expect(find.textContaining('conexão'), findsOneWidget);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();

    verify(() => cubit.reload()).called(1);
  });

  testWidgets('shows a spinner while the first numbers load', (tester) async {
    await show(tester, loaded(withData: null, status: TaxReserveStatus.loading));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('says when the percentage could not be saved', (tester) async {
    await show(
      tester,
      loaded(),
      later: Stream.value(
        TaxReserveState(
          status: TaxReserveStatus.loaded,
          month: october,
          currentMonth: october,
          data: data,
          saveFailure: const RuleFailure('violates check constraint'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Algo deu errado. Tente novamente.'), findsOneWidget);
  });

  testWidgets('explains how the numbers are made, and to ask an accountant', (tester) async {
    await show(tester, loaded());

    await tester.tap(find.text('Como calculamos'));
    await tester.pumpAndSettle();

    expect(find.textContaining('contador'), findsOneWidget);
  });
}
