import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:finly/features/dashboard/domain/usecases/get_dashboard_use_case.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetDashboard extends Mock implements GetDashboardUseCase {}

void main() {
  late MockGetDashboard getDashboard;

  final now = DateTime(2026, 10, 5, 14, 30);
  final params = GetDashboardParams(workspaceId: 'w1', today: now);
  final data = DashboardData(
    month: DateTime(2026, 10),
    accountCount: 1,
    balances: const [],
    flows: const [],
    budgets: const [],
    upcoming: const [],
  );

  setUpAll(() => registerFallbackValue(params));

  setUp(() => getDashboard = MockGetDashboard());

  DashboardCubit buildCubit() =>
      DashboardCubit(getDashboard, clock: () => now);

  blocTest<DashboardCubit, DashboardState>(
    'load emits loading then the data',
    build: () {
      when(() => getDashboard(params))
          .thenAnswer((_) async => Right<Failure, DashboardData>(data));
      return buildCubit();
    },
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const DashboardState(status: DashboardStatus.loading),
      DashboardState(status: DashboardStatus.loaded, data: data),
    ],
  );

  blocTest<DashboardCubit, DashboardState>(
    'load emits loading then failure',
    build: () {
      when(() => getDashboard(params)).thenAnswer(
        (_) async => const Left<Failure, DashboardData>(
          NetworkFailure('network_error'),
        ),
      );
      return buildCubit();
    },
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const DashboardState(status: DashboardStatus.loading),
      const DashboardState(
        status: DashboardStatus.failure,
        failure: NetworkFailure('network_error'),
      ),
    ],
  );

  blocTest<DashboardCubit, DashboardState>(
    'a failed reload keeps the numbers that were already on screen',
    build: () {
      var calls = 0;
      when(() => getDashboard(any())).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? Right<Failure, DashboardData>(data)
            : const Left<Failure, DashboardData>(
                NetworkFailure('network_error'),
              );
      });
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.load('w1');
      await cubit.reload();
    },
    skip: 2,
    expect: () => [
      DashboardState(status: DashboardStatus.loading, data: data),
      DashboardState(
        status: DashboardStatus.failure,
        data: data,
        failure: const NetworkFailure('network_error'),
      ),
    ],
  );

  blocTest<DashboardCubit, DashboardState>(
    'reload asks again for the same workspace',
    build: () {
      when(() => getDashboard(params))
          .thenAnswer((_) async => Right<Failure, DashboardData>(data));
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.load('w1');
      await cubit.reload();
    },
    verify: (_) => verify(() => getDashboard(params)).called(2),
  );

  blocTest<DashboardCubit, DashboardState>(
    'reload does nothing before the first load',
    build: buildCubit,
    act: (cubit) => cubit.reload(),
    expect: () => <DashboardState>[],
    verify: (_) => verifyNever(() => getDashboard(any())),
  );
}