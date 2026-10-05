import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:finly/features/budgets/domain/entities/budget_overview.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/budgets/domain/usecases/get_budget_overview_use_case.dart';
import 'package:finly/features/budgets/domain/usecases/stop_budget_use_case.dart';
import 'package:finly/features/budgets/presentation/cubit/budgets_cubit.dart';
import 'package:finly/features/budgets/presentation/cubit/budgets_state.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetOverview extends Mock implements GetBudgetOverviewUseCase {}

class MockStopBudget extends Mock implements StopBudgetUseCase {}

void main() {
  late MockGetOverview getOverview;
  late MockStopBudget stopBudget;

  final march = DateTime(2026, 3);
  final april = DateTime(2026, 4);

  const category = CategoryEntity(
    id: 'c1',
    workspaceId: 'w1',
    name: 'Alimentação',
    kind: CategoryKind.expense,
    icon: 'restaurant',
    colorHex: '#F29D38',
    isDefault: true,
  );
  final item = BudgetProgress(
    budget: BudgetEntity(
      id: 'b1',
      workspaceId: 'w1',
      categoryId: 'c1',
      effectiveFrom: march,
      limitCents: 80000,
      currency: 'BRL',
    ),
    category: category,
    spentCents: 1000,
  );

  BudgetOverview overviewOf(DateTime month) => BudgetOverview(
        month: month,
        items: const [],
        expenseCategories: const [],
        withoutBudget: const [],
      );

  GetBudgetOverviewParams params(DateTime month) =>
      GetBudgetOverviewParams(workspaceId: 'w1', month: month);

  void stubMonth(DateTime month) {
    when(() => getOverview(params(month))).thenAnswer(
      (_) async => Right<Failure, BudgetOverview>(overviewOf(month)),
    );
  }

    setUpAll(() {
    registerFallbackValue(params(DateTime(2026)));
    registerFallbackValue(
      StopBudgetParams(
        workspaceId: 'w',
        categoryId: 'c',
        month: DateTime(2026),
        currency: 'BRL',
      ),
    );
  });

  setUp(() {
    getOverview = MockGetOverview();
    stopBudget = MockStopBudget();
  });

  BudgetsCubit buildCubit() => BudgetsCubit(
        getOverview: getOverview,
        stopBudget: stopBudget,
        clock: () => DateTime(2026, 3, 15),
      );

  test('starts on the month of today', () {
    expect(buildCubit().state, BudgetsState(month: march));
  });

  blocTest<BudgetsCubit, BudgetsState>(
    'load emits loading then the overview of the current month',
    build: () {
      stubMonth(march);
      return buildCubit();
    },
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      BudgetsState(status: BudgetsStatus.loading, month: march),
      BudgetsState(
        status: BudgetsStatus.loaded,
        month: march,
        overview: overviewOf(march),
      ),
    ],
  );

  blocTest<BudgetsCubit, BudgetsState>(
    'load emits loading then failure',
    build: () {
      when(() => getOverview(params(march))).thenAnswer(
        (_) async => const Left<Failure, BudgetOverview>(
          NetworkFailure('network_error'),
        ),
      );
      return buildCubit();
    },
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      BudgetsState(status: BudgetsStatus.loading, month: march),
      BudgetsState(
        status: BudgetsStatus.failure,
        month: march,
        failure: const NetworkFailure('network_error'),
      ),
    ],
  );

  blocTest<BudgetsCubit, BudgetsState>(
    'changing the month starts empty, so old numbers never sit under a new title',
    build: () {
      stubMonth(march);
      stubMonth(april);
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.load('w1');
      await cubit.changeMonth(1);
    },
    expect: () => [
      BudgetsState(status: BudgetsStatus.loading, month: march),
      BudgetsState(
        status: BudgetsStatus.loaded,
        month: march,
        overview: overviewOf(march),
      ),
      BudgetsState(status: BudgetsStatus.loading, month: april),
      BudgetsState(
        status: BudgetsStatus.loaded,
        month: april,
        overview: overviewOf(april),
      ),
    ],
  );

  blocTest<BudgetsCubit, BudgetsState>(
    'changeMonth does nothing before the first load',
    build: buildCubit,
    act: (cubit) => cubit.changeMonth(1),
    expect: () => <BudgetsState>[],
    verify: (_) => verifyNever(() => getOverview(any())),
  );

  blocTest<BudgetsCubit, BudgetsState>(
    'stopping a budget ends it from the month on screen and reloads',
    build: () {
      stubMonth(march);
      when(() => stopBudget(any())).thenAnswer(
        (_) async => Right<Failure, BudgetEntity>(item.budget),
      );
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.load('w1');
      await cubit.stopBudget(item);
    },
    verify: (_) {
      verify(
        () => stopBudget(
          StopBudgetParams(
            workspaceId: 'w1',
            categoryId: 'c1',
            month: march,
            currency: 'BRL',
          ),
        ),
      ).called(1);
      verify(() => getOverview(params(march))).called(2);
    },
  );

  blocTest<BudgetsCubit, BudgetsState>(
    'a refused stop keeps the overview and reports the reason',
    build: () {
      stubMonth(march);
      when(() => stopBudget(any())).thenAnswer(
        (_) async =>
            const Left<Failure, BudgetEntity>(PermissionFailure('forbidden')),
      );
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.load('w1');
      await cubit.stopBudget(item);
    },
    skip: 2,
    expect: () => [
      BudgetsState(
        status: BudgetsStatus.loaded,
        month: march,
        overview: overviewOf(march),
        actionFailure: const PermissionFailure('forbidden'),
      ),
    ],
  );
}