import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/appearance/data/datasources/appearance_remote_data_source.dart';
import 'package:finly/features/appearance/data/repositories/appearance_repository_impl.dart';
import 'package:finly/features/appearance/domain/entities/appearance_mode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRemote extends Mock implements AppearanceRemoteDataSource {}

void main() {
  late MockRemote remote;
  late AppearanceRepositoryImpl repository;

  setUpAll(() => registerFallbackValue(AppearanceMode.system));

  setUp(() {
    remote = MockRemote();
    repository = AppearanceRepositoryImpl(remote);
  });

  test('getMode returns what the data source read', () async {
    when(() => remote.getMode()).thenAnswer((_) async => AppearanceMode.dark);

    final result = await repository.getMode();

    expect(result, const Right<Failure, AppearanceMode>(AppearanceMode.dark));
  });

  test('saveMode sends the choice to the data source', () async {
    when(() => remote.saveMode(any())).thenAnswer((_) async {});

    final result = await repository.saveMode(AppearanceMode.light);

    expect(result.isRight(), isTrue);
    verify(() => remote.saveMode(AppearanceMode.light)).called(1);
  });

  test('a timeout becomes NetworkFailure', () async {
    when(() => remote.getMode()).thenThrow(TimeoutException('slow'));

    final result = await repository.getMode();

    expect(result, const Left<Failure, AppearanceMode>(NetworkFailure('network_error')));
  });

  test('an unexpected error becomes a failure instead of escaping', () async {
    when(() => remote.saveMode(any())).thenThrow(StateError('boom'));

    final result = await repository.saveMode(AppearanceMode.dark);

    expect(result, const Left<Failure, void>(ServerFailure('unknown_error')));
  });
}
