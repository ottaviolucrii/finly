import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/dashboard/domain/entities/dashboard_charts.dart';
import 'package:finly/features/dashboard/domain/usecases/get_dashboard_charts_use_case.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_charts_cubit.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_charts_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetCharts extends Mock implements GetDashboardChartsUseCase {}

void main() {
  late MockGetCharts getCharts;

  final now = DateTime(2026, 10, 6, 10);
  final params = GetDashboardChartsParams(workspaceId: 'w1', today: now);
  final charts = DashboardCharts(month: DateTime(2026, 10), byCurrency: const []);

  setUpAll(() => registerFallbackValue(params));

  setUp(() => getCharts = MockGetCharts());

  DashboardChartsCubit buildCubit() =>
      DashboardChartsCubit(getCharts, clock: () => now);

  blocTest<DashboardChartsCubit, DashboardChartsState>(
    'load emits loading then the charts',
    build: () {
      when(() => getCharts(params))
          .thenAnswer((_) async => Right<Failure, DashboardCharts>(charts));
      return buildCubit();
    },
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const DashboardChartsState(status: DashboardChartsStatus.loading),
      DashboardChartsState(status: DashboardChartsStatus.loaded, charts: charts),
    ],
  );

  blocTest<DashboardChartsCubit, DashboardChartsState>(
    'a failed reload keeps the charts that were already there',
    build: () {
      var calls = 0;
      when(() => getCharts(any())).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? Right<Failure, DashboardCharts>(charts)
            : const Left<Failure, DashboardCharts>(NetworkFailure('network_error'));
      });
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.load('w1');
      await cubit.reload();
    },
    skip: 2,
    expect: () => [
      DashboardChartsState(status: DashboardChartsStatus.loading, charts: charts),
      DashboardChartsState(
        status: DashboardChartsStatus.failure,
        charts: charts,
        failure: const NetworkFailure('network_error'),
      ),
    ],
  );

  blocTest<DashboardChartsCubit, DashboardChartsState>(
    'reload does nothing before the first load',
    build: buildCubit,
    act: (cubit) => cubit.reload(),
    expect: () => <DashboardChartsState>[],
    verify: (_) => verifyNever(() => getCharts(any())),
  );
}