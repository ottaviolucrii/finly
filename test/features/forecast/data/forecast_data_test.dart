import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/forecast/data/datasources/forecast_remote_data_source.dart';
import 'package:finly/features/forecast/data/repositories/forecast_repository_impl.dart';
import 'package:finly/features/forecast/domain/entities/forecast_items.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRemote extends Mock implements ForecastRemoteDataSource {}

void main() {
  late MockRemote remote;
  late ForecastRepositoryImpl repository;

  final until = DateTime(2027, 1, 5);

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    remote = MockRemote();
    repository = ForecastRepositoryImpl(remote);
  });

  test('returns what the data source read', () async {
    const inputs = ForecastInputs(startingBalances: {'BRL': 100000});
    when(() => remote.getInputs('w1', until: until)).thenAnswer((_) async => inputs);

    final result = await repository.getInputs('w1', until: until);

    expect(result, const Right<Failure, ForecastInputs>(inputs));
  });

  test('a timeout becomes NetworkFailure', () async {
    when(() => remote.getInputs(any(), until: any(named: 'until')))
        .thenThrow(TimeoutException('slow'));

    final result = await repository.getInputs('w1', until: until);

    expect(result, const Left<Failure, ForecastInputs>(NetworkFailure('network_error')));
  });

  test('an unexpected error becomes a failure instead of escaping', () async {
    when(() => remote.getInputs(any(), until: any(named: 'until')))
        .thenThrow(StateError('boom'));

    final result = await repository.getInputs('w1', until: until);

    expect(result, const Left<Failure, ForecastInputs>(ServerFailure('unknown_error')));
  });

  test('an unknown recurrence label becomes a failure, not a crash', () async {
    when(() => remote.getInputs(any(), until: any(named: 'until')))
        .thenAnswer((_) async => throw ArgumentError('fortnightly'));

    final result = await repository.getInputs('w1', until: until);

    expect(result.isLeft(), isTrue);
  });
}
