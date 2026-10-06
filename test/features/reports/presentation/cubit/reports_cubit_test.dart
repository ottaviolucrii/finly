import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/reports/domain/entities/monthly_report.dart';
import 'package:finly/features/reports/domain/usecases/get_monthly_report_use_case.dart';
import 'package:finly/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:finly/features/reports/presentation/cubit/reports_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetReport extends Mock implements GetMonthlyReportUseCase {}

void main() {
  late MockGetReport getReport;

  final now = DateTime(2026, 10, 6, 10);
  final october = DateTime(2026, 10);
  final september = DateTime(2026, 9);

  MonthlyReport reportOf(DateTime month) =>
      MonthlyReport(month: month, byCurrency: const []);

  GetMonthlyReportParams paramsFor(DateTime month) =>
      GetMonthlyReportParams(workspaceId: 'w1', month: month);

  setUpAll(() => registerFallbackValue(paramsFor(october)));

  setUp(() {
    getReport = MockGetReport();
    when(() => getReport(any())).thenAnswer((invocation) async {
      final p = invocation.positionalArguments.first as GetMonthlyReportParams;
      return Right<Failure, MonthlyReport>(reportOf(p.month));
    });
  });

  ReportsCubit buildCubit() => ReportsCubit(getReport, clock: () => now);

  test('starts on the current month, which cannot go further', () {
    final cubit = buildCubit();

    expect(cubit.state.month, october);
    expect(cubit.state.currentMonth, october);
    expect(cubit.state.canGoNext, isFalse);
    cubit.close();
  });

  blocTest<ReportsCubit, ReportsState>(
    'load emits loading then the report of the current month',
    build: buildCubit,
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      ReportsState(
        status: ReportsStatus.loading,
        month: october,
        currentMonth: october,
      ),
      ReportsState(
        status: ReportsStatus.loaded,
        month: october,
        currentMonth: october,
        report: reportOf(october),
      ),
    ],
  );

  blocTest<ReportsCubit, ReportsState>(
    'previousMonth loads the month before and keeps the old report meanwhile',
    build: buildCubit,
    act: (cubit) async {
      await cubit.load('w1');
      await cubit.previousMonth();
    },
    skip: 2,
    expect: () => [
      ReportsState(
        status: ReportsStatus.loading,
        month: september,
        currentMonth: october,
        report: reportOf(october),
      ),
      ReportsState(
        status: ReportsStatus.loaded,
        month: september,
        currentMonth: october,
        report: reportOf(september),
      ),
    ],
  );

  blocTest<ReportsCubit, ReportsState>(
    'nextMonth goes forward after going back, but never past the current month',
    build: buildCubit,
    act: (cubit) async {
      await cubit.load('w1');
      await cubit.previousMonth();
      await cubit.nextMonth();
      await cubit.nextMonth();
    },
    verify: (cubit) {
      expect(cubit.state.month, october);
      expect(cubit.state.canGoNext, isFalse);
      // october, september, october again: the last nextMonth did nothing.
      verify(() => getReport(any())).called(3);
    },
  );

  blocTest<ReportsCubit, ReportsState>(
    'a failure keeps the last report and reports the reason',
    build: () {
      var calls = 0;
      when(() => getReport(any())).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? Right<Failure, MonthlyReport>(reportOf(october))
            : const Left<Failure, MonthlyReport>(NetworkFailure('network_error'));
      });
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.load('w1');
      await cubit.previousMonth();
    },
    skip: 3,
    expect: () => [
      ReportsState(
        status: ReportsStatus.failure,
        month: september,
        currentMonth: october,
        report: reportOf(october),
        failure: const NetworkFailure('network_error'),
      ),
    ],
  );

  blocTest<ReportsCubit, ReportsState>(
    'navigating before the first load does nothing',
    build: buildCubit,
    act: (cubit) => cubit.previousMonth(),
    expect: () => <ReportsState>[],
    verify: (_) => verifyNever(() => getReport(any())),
  );
}