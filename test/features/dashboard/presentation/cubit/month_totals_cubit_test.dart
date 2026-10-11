import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/dashboard/domain/entities/monthly_flow_entry.dart';
import 'package:finly/features/dashboard/domain/usecases/get_month_totals_use_case.dart';
import 'package:finly/features/dashboard/presentation/cubit/month_totals_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetMonthTotals extends Mock implements GetMonthTotalsUseCase {}

void main() {
  late MockGetMonthTotals getTotals;

  final october = DateTime(2026, 10);
  final november = DateTime(2026, 11);
  final octoberTotals = MonthlyFlowEntry(month: october, currency: 'BRL', incomeCents: 820000, expenseCents: 573190);
  final novemberTotals = MonthlyFlowEntry(month: november, currency: 'BRL', incomeCents: 100, expenseCents: 0);

  setUpAll(() => registerFallbackValue(GetMonthTotalsParams(workspaceId: 'w1', month: october)));

  setUp(() => getTotals = MockGetMonthTotals());

  void stub(DateTime month, Either<Failure, List<MonthlyFlowEntry>> answer) {
    when(() => getTotals(GetMonthTotalsParams(workspaceId: 'w1', month: month))).thenAnswer((_) async => answer);
  }

  blocTest<MonthTotalsCubit, MonthTotalsState>(
    'loads the totals of the month',
    setUp: () => stub(october, Right([octoberTotals])),
    build: () => MonthTotalsCubit(getTotals),
    act: (cubit) => cubit.load('w1', DateTime(2026, 10, 10, 9)),
    expect: () => [
      MonthTotalsState(status: MonthTotalsStatus.loading, month: october),
      MonthTotalsState(status: MonthTotalsStatus.loaded, month: october, entries: [octoberTotals]),
    ],
  );

  blocTest<MonthTotalsCubit, MonthTotalsState>(
    'keeps the numbers on screen while the same month reloads',
    setUp: () => stub(october, Right([octoberTotals])),
    build: () => MonthTotalsCubit(getTotals),
    seed: () => MonthTotalsState(status: MonthTotalsStatus.loaded, month: october, entries: [octoberTotals]),
    act: (cubit) => cubit.load('w1', october),
    expect: () => [
      MonthTotalsState(status: MonthTotalsStatus.loading, month: october, entries: [octoberTotals]),
      MonthTotalsState(status: MonthTotalsStatus.loaded, month: october, entries: [octoberTotals]),
    ],
  );

  blocTest<MonthTotalsCubit, MonthTotalsState>(
    'clears the numbers when moving to another month',
    setUp: () => stub(november, Right([novemberTotals])),
    build: () => MonthTotalsCubit(getTotals),
    seed: () => MonthTotalsState(status: MonthTotalsStatus.loaded, month: october, entries: [octoberTotals]),
    act: (cubit) => cubit.load('w1', november),
    expect: () => [
      MonthTotalsState(status: MonthTotalsStatus.loading, month: november),
      MonthTotalsState(status: MonthTotalsStatus.loaded, month: november, entries: [novemberTotals]),
    ],
  );

  blocTest<MonthTotalsCubit, MonthTotalsState>(
    'shows a failure',
    setUp: () => stub(october, const Left(NetworkFailure('network_error'))),
    build: () => MonthTotalsCubit(getTotals),
    act: (cubit) => cubit.load('w1', october),
    expect: () => [
      MonthTotalsState(status: MonthTotalsStatus.loading, month: october),
      MonthTotalsState(status: MonthTotalsStatus.failure, month: october, failure: const NetworkFailure('network_error')),
    ],
  );

  test('an old answer never replaces a newer month', () async {
    final slow = Completer<Either<Failure, List<MonthlyFlowEntry>>>();
    when(() => getTotals(GetMonthTotalsParams(workspaceId: 'w1', month: october))).thenAnswer((_) => slow.future);
    stub(november, Right([novemberTotals]));
    final cubit = MonthTotalsCubit(getTotals);

    final first = cubit.load('w1', october);
    await cubit.load('w1', november);
    slow.complete(Right([octoberTotals]));
    await first;

    expect(cubit.state.month, november);
    expect(cubit.state.entries, [novemberTotals]);
    await cubit.close();
  });

  test('reload reads the same month again', () async {
    stub(october, Right([octoberTotals]));
    final cubit = MonthTotalsCubit(getTotals);

    await cubit.load('w1', october);
    await cubit.reload();

    verify(() => getTotals(GetMonthTotalsParams(workspaceId: 'w1', month: october))).called(2);
    await cubit.close();
  });

  test('reload does nothing before the first load', () async {
    final cubit = MonthTotalsCubit(getTotals);

    await cubit.reload();

    verifyNever(() => getTotals(any()));
    await cubit.close();
  });

  test('main is the first currency, or nothing', () {
    expect(const MonthTotalsState().main, isNull);
    expect(MonthTotalsState(entries: [octoberTotals, novemberTotals]).main, octoberTotals);
  });
}
