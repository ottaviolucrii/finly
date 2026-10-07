import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/forecast/domain/entities/forecast_items.dart';
import 'package:finly/features/forecast/domain/usecases/get_forecast_use_case.dart';
import 'package:finly/features/forecast/presentation/cubit/forecast_cubit.dart';
import 'package:finly/features/forecast/presentation/cubit/forecast_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetForecast extends Mock implements GetForecastUseCase {}

void main() {
  late MockGetForecast getForecast;

  final now = DateTime(2026, 10, 6, 14, 20);
  final today = DateTime(2026, 10, 6);
  final params = GetForecastParams(workspaceId: 'w1', today: now);

  final forecast = Forecast(
    currency: 'BRL',
    startCents: 1000,
    points: [ForecastPoint(date: DateTime(2026, 10, 6), balanceCents: 1000)],
    events: [],
  );

  setUpAll(() => registerFallbackValue(params));

  setUp(() => getForecast = MockGetForecast());

  ForecastCubit build() => ForecastCubit(getForecast, clock: () => now);

  blocTest<ForecastCubit, ForecastState>(
    'load emits loading then the forecasts, with today as a date',
    build: () {
      when(() => getForecast(params))
          .thenAnswer((_) async => Right<Failure, List<Forecast>>([forecast]));
      return build();
    },
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const ForecastState(status: ForecastStatus.loading),
      ForecastState(status: ForecastStatus.loaded, forecasts: [forecast], today: today),
    ],
  );

  blocTest<ForecastCubit, ForecastState>(
    'load emits loading then the failure',
    build: () {
      when(() => getForecast(params)).thenAnswer(
        (_) async => const Left<Failure, List<Forecast>>(NetworkFailure('network_error')),
      );
      return build();
    },
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const ForecastState(status: ForecastStatus.loading),
      const ForecastState(
        status: ForecastStatus.failure,
        failure: NetworkFailure('network_error'),
      ),
    ],
  );

  blocTest<ForecastCubit, ForecastState>(
    'a reload keeps the old forecasts on screen, also when it fails',
    build: () {
      var calls = 0;
      when(() => getForecast(any())).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? Right<Failure, List<Forecast>>([forecast])
            : const Left<Failure, List<Forecast>>(NetworkFailure('network_error'));
      });
      return build();
    },
    act: (cubit) async {
      await cubit.load('w1');
      await cubit.reload();
    },
    skip: 2,
    expect: () => [
      ForecastState(status: ForecastStatus.loading, forecasts: [forecast], today: today),
      ForecastState(
        status: ForecastStatus.failure,
        forecasts: [forecast],
        today: today,
        failure: const NetworkFailure('network_error'),
      ),
    ],
  );

  blocTest<ForecastCubit, ForecastState>(
    'reload does nothing before the first load',
    build: build,
    act: (cubit) => cubit.reload(),
    expect: () => <ForecastState>[],
    verify: (_) => verifyNever(() => getForecast(any())),
  );
}
