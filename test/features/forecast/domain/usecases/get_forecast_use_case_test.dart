import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/forecast/domain/entities/forecast_items.dart';
import 'package:finly/features/forecast/domain/repositories/forecast_repository.dart';
import 'package:finly/features/forecast/domain/usecases/get_forecast_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRepository extends Mock implements ForecastRepository {}

void main() {
  late MockRepository repository;
  late GetForecastUseCase useCase;

  final now = DateTime(2026, 10, 6, 15, 30);

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    repository = MockRepository();
    useCase = GetForecastUseCase(repository);
  });

  test('rejects an empty workspace id', () async {
    final result = await useCase(GetForecastParams(workspaceId: ' ', today: now));

    expect(result, const Left<Failure, List<Forecast>>(ValidationFailure('invalid_workspace')));
    verifyNever(() => repository.getInputs(any(), until: any(named: 'until')));
  });

  test('asks for the next 90 days, with the end excluded', () async {
    when(() => repository.getInputs('w1', until: DateTime(2027, 1, 5))).thenAnswer(
      (_) async => const Right<Failure, ForecastInputs>(ForecastInputs()),
    );

    await useCase(GetForecastParams(workspaceId: 'w1', today: now));

    verify(() => repository.getInputs('w1', until: DateTime(2027, 1, 5))).called(1);
  });

  test('builds one forecast per currency from what the repository returns', () async {
    when(() => repository.getInputs('w1', until: any(named: 'until'))).thenAnswer(
      (_) async => const Right<Failure, ForecastInputs>(
        ForecastInputs(startingBalances: {'BRL': 100000, 'USD': 5000}),
      ),
    );

    final result = await useCase(GetForecastParams(workspaceId: 'w1', today: now));

    result.fold(
      (failure) => fail('expected forecasts, got $failure'),
      (forecasts) {
        expect(forecasts.map((f) => f.currency), ['BRL', 'USD']);
        expect(forecasts.first.points.first.date, DateTime(2026, 10, 6));
        expect(forecasts.first.days, 90);
      },
    );
  });

  test('is empty when the workspace has nothing', () async {
    when(() => repository.getInputs('w1', until: any(named: 'until'))).thenAnswer(
      (_) async => const Right<Failure, ForecastInputs>(ForecastInputs()),
    );

    final result = await useCase(GetForecastParams(workspaceId: 'w1', today: now));

    expect(result.getOrElse(() => [const Forecast(currency: 'x', startCents: 0, points: [], events: [])]), isEmpty);
  });

  test('passes a failure through unchanged', () async {
    when(() => repository.getInputs(any(), until: any(named: 'until'))).thenAnswer(
      (_) async => const Left<Failure, ForecastInputs>(NetworkFailure('network_error')),
    );

    final result = await useCase(GetForecastParams(workspaceId: 'w1', today: now));

    expect(result, const Left<Failure, List<Forecast>>(NetworkFailure('network_error')));
  });
}
