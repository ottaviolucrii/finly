import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/tax_reserve/domain/entities/tax_reserve_data.dart';
import 'package:finly/features/tax_reserve/domain/usecases/get_tax_reserve_use_case.dart';
import 'package:finly/features/tax_reserve/domain/usecases/save_tax_reserve_percent_use_case.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_reserve_cubit.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_reserve_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGet extends Mock implements GetTaxReserveUseCase {}

class MockSave extends Mock implements SaveTaxReservePercentUseCase {}

void main() {
  late MockGet getTaxReserve;
  late MockSave savePercent;

  final october = DateTime(2026, 10);
  final september = DateTime(2026, 9);

  const octoberData = TaxReserveData(
    percentBps: 650,
    currency: 'BRL',
    incomeCents: 500000,
    taxCents: 12000,
  );
  const septemberData = TaxReserveData(
    percentBps: 650,
    currency: 'BRL',
    incomeCents: 300000,
    taxCents: 0,
  );

  setUpAll(() {
    registerFallbackValue(GetTaxReserveParams(workspaceId: 'w1', month: october));
    registerFallbackValue(const SaveTaxReservePercentParams(workspaceId: 'w1', percentBps: 1));
  });

  setUp(() {
    getTaxReserve = MockGet();
    savePercent = MockSave();
  });

  TaxReserveCubit build() => TaxReserveCubit(
        getTaxReserve: getTaxReserve,
        savePercent: savePercent,
        clock: () => DateTime(2026, 10, 7, 15),
      );

  GetTaxReserveParams forMonth(DateTime month) =>
      GetTaxReserveParams(workspaceId: 'w1', month: month);

  void stubMonth(DateTime month, TaxReserveData data) {
    when(() => getTaxReserve(forMonth(month)))
        .thenAnswer((_) async => Right<Failure, TaxReserveData>(data));
  }

  test('starts on the current month, loading', () {
    final cubit = build();

    expect(cubit.state.month, october);
    expect(cubit.state.currentMonth, october);
    expect(cubit.state.status, TaxReserveStatus.loading);
    expect(cubit.state.data, isNull);
    expect(cubit.state.canGoNext, isFalse);
    cubit.close();
  });

  test('load shows the data of the current month', () async {
    stubMonth(october, octoberData);
    final cubit = build();
    final states = <TaxReserveState>[];
    final subscription = cubit.stream.listen(states.add);

    await cubit.load('w1');
    // The stream hands its events over a moment after they are emitted.
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();

    expect(states.map((s) => s.status), [TaxReserveStatus.loading, TaxReserveStatus.loaded]);
    expect(states.last.data, octoberData);
    await cubit.close();
  });

  test('a failure is shown and there is nothing to show yet', () async {
    when(() => getTaxReserve(any())).thenAnswer(
      (_) async => const Left<Failure, TaxReserveData>(NetworkFailure('network_error')),
    );
    final cubit = build();

    await cubit.load('w1');

    expect(cubit.state.status, TaxReserveStatus.failure);
    expect(cubit.state.failure, const NetworkFailure('network_error'));
    expect(cubit.state.data, isNull);
    await cubit.close();
  });

  test('reload before the first load does nothing', () async {
    final cubit = build();

    await cubit.reload();

    verifyNever(() => getTaxReserve(any()));
    await cubit.close();
  });

  test('previousMonth keeps the old numbers on screen while the new ones load', () async {
    stubMonth(october, octoberData);
    final gate = Completer<Either<Failure, TaxReserveData>>();
    when(() => getTaxReserve(forMonth(september))).thenAnswer((_) => gate.future);
    final cubit = build();
    await cubit.load('w1');

    final going = cubit.previousMonth();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.month, september);
    expect(cubit.state.status, TaxReserveStatus.loading);
    expect(cubit.state.data, octoberData);

    gate.complete(const Right<Failure, TaxReserveData>(septemberData));
    await going;

    expect(cubit.state.status, TaxReserveStatus.loaded);
    expect(cubit.state.data, septemberData);
    expect(cubit.state.canGoNext, isTrue);
    await cubit.close();
  });

  test('nextMonth does nothing on the current month', () async {
    stubMonth(october, octoberData);
    final cubit = build();
    await cubit.load('w1');
    clearInteractions(getTaxReserve);

    await cubit.nextMonth();

    verifyNever(() => getTaxReserve(any()));
    expect(cubit.state.month, october);
    await cubit.close();
  });

  test('nextMonth goes forward after going back', () async {
    stubMonth(october, octoberData);
    stubMonth(september, septemberData);
    final cubit = build();
    await cubit.load('w1');
    await cubit.previousMonth();

    await cubit.nextMonth();

    expect(cubit.state.month, october);
    expect(cubit.state.data, octoberData);
    await cubit.close();
  });

  test('a slow answer for a month the person left never replaces the newer one', () async {
    final slow = Completer<Either<Failure, TaxReserveData>>();
    when(() => getTaxReserve(forMonth(october))).thenAnswer((_) => slow.future);
    stubMonth(september, septemberData);
    final cubit = build();

    final first = cubit.load('w1');
    await cubit.previousMonth();
    slow.complete(const Right<Failure, TaxReserveData>(octoberData));
    await first;

    expect(cubit.state.month, september);
    expect(cubit.state.data, septemberData);
    await cubit.close();
  });

  group('savePercent', () {
    test('shows the new percentage at once and keeps it when it is saved', () async {
      stubMonth(october, octoberData);
      final gate = Completer<Either<Failure, void>>();
      when(() => savePercent(any())).thenAnswer((_) => gate.future);
      final cubit = build();
      await cubit.load('w1');

      final saving = cubit.savePercent(1000);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.saving, isTrue);
      expect(cubit.state.data!.percentBps, 1000);

      gate.complete(const Right<Failure, void>(null));
      await saving;

      expect(cubit.state.saving, isFalse);
      expect(cubit.state.saveFailure, isNull);
      expect(cubit.state.data!.percentBps, 1000);
      expect(cubit.state.data!.reserveCents, 50000);
      verify(() => savePercent(
            const SaveTaxReservePercentParams(workspaceId: 'w1', percentBps: 1000),
          )).called(1);
      await cubit.close();
    });

    test('a refused save puts the old percentage back and says why', () async {
      stubMonth(october, octoberData);
      when(() => savePercent(any())).thenAnswer(
        (_) async => const Left<Failure, void>(RuleFailure('violates check constraint')),
      );
      final cubit = build();
      await cubit.load('w1');

      await cubit.savePercent(1000);

      expect(cubit.state.data!.percentBps, 650);
      expect(cubit.state.saving, isFalse);
      expect(cubit.state.saveFailure, const RuleFailure('violates check constraint'));
      await cubit.close();
    });

    test('the next load clears the old save failure', () async {
      stubMonth(october, octoberData);
      when(() => savePercent(any())).thenAnswer(
        (_) async => const Left<Failure, void>(NetworkFailure('network_error')),
      );
      final cubit = build();
      await cubit.load('w1');
      await cubit.savePercent(1000);

      await cubit.reload();

      expect(cubit.state.saveFailure, isNull);
      await cubit.close();
    });

    test('does nothing before the data is loaded', () async {
      final cubit = build();

      await cubit.savePercent(1000);

      verifyNever(() => savePercent(any()));
      await cubit.close();
    });

    test('a second save while one is running is ignored', () async {
      stubMonth(october, octoberData);
      final gate = Completer<Either<Failure, void>>();
      when(() => savePercent(any())).thenAnswer((_) => gate.future);
      final cubit = build();
      await cubit.load('w1');

      final first = cubit.savePercent(1000);
      await Future<void>.delayed(Duration.zero);
      await cubit.savePercent(2000);
      gate.complete(const Right<Failure, void>(null));
      await first;

      verify(() => savePercent(any())).called(1);
      expect(cubit.state.data!.percentBps, 1000);
      await cubit.close();
    });
  });
}
