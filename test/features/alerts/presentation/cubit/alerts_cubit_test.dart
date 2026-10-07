import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/alerts/domain/entities/app_alert.dart';
import 'package:finly/features/alerts/domain/usecases/get_alerts_use_case.dart';
import 'package:finly/features/alerts/presentation/cubit/alerts_cubit.dart';
import 'package:finly/features/alerts/presentation/cubit/alerts_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAlerts extends Mock implements GetAlertsUseCase {}

void main() {
  late MockGetAlerts getAlerts;

  final now = DateTime(2026, 10, 6, 10);
  final params = GetAlertsParams(workspaceId: 'w1', today: now);
  const alert = AppAlert(
    kind: AlertKind.billOverdue,
    subject: 'Aluguel',
    currency: 'BRL',
    amountCents: 150000,
    daysUntilDue: -2,
  );

  setUpAll(() => registerFallbackValue(params));

  setUp(() => getAlerts = MockGetAlerts());

  AlertsCubit buildCubit() => AlertsCubit(getAlerts, clock: () => now);

  blocTest<AlertsCubit, AlertsState>(
    'load emits loading then the alerts',
    build: () {
      when(() => getAlerts(params))
          .thenAnswer((_) async => const Right<Failure, List<AppAlert>>([alert]));
      return buildCubit();
    },
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const AlertsState(status: AlertsStatus.loading),
      const AlertsState(status: AlertsStatus.loaded, alerts: [alert]),
    ],
  );

  blocTest<AlertsCubit, AlertsState>(
    'a failed reload keeps the alerts that were already there',
    build: () {
      var calls = 0;
      when(() => getAlerts(any())).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? const Right<Failure, List<AppAlert>>([alert])
            : const Left<Failure, List<AppAlert>>(NetworkFailure('network_error'));
      });
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.load('w1');
      await cubit.reload();
    },
    skip: 2,
    expect: () => [
      const AlertsState(status: AlertsStatus.loading, alerts: [alert]),
      const AlertsState(
        status: AlertsStatus.failure,
        alerts: [alert],
        failure: NetworkFailure('network_error'),
      ),
    ],
  );

  blocTest<AlertsCubit, AlertsState>(
    'reload does nothing before the first load',
    build: buildCubit,
    act: (cubit) => cubit.reload(),
    expect: () => <AlertsState>[],
    verify: (_) => verifyNever(() => getAlerts(any())),
  );
}