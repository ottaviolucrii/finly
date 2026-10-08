import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/tax_reserve/data/datasources/tax_reserve_remote_data_source.dart';
import 'package:finly/features/tax_reserve/data/repositories/tax_reserve_repository_impl.dart';
import 'package:finly/features/tax_reserve/domain/entities/tax_reserve_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements TaxReserveRemoteDataSource {}

void main() {
  late MockRemote remote;
  late TaxReserveRepositoryImpl repository;

  const data = TaxReserveData(
    percentBps: 650,
    currency: 'BRL',
    incomeCents: 500000,
    taxCents: 12000,
  );

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    remote = MockRemote();
    repository = TaxReserveRepositoryImpl(remote);
  });

  group('getData', () {
    test('returns what the data source read', () async {
      when(() => remote.getData('w1', DateTime(2026, 10))).thenAnswer((_) async => data);

      final result = await repository.getData('w1', DateTime(2026, 10));

      expect(result, const Right<Failure, TaxReserveData>(data));
    });

    test('a timeout becomes NetworkFailure', () async {
      when(() => remote.getData(any(), any())).thenThrow(TimeoutException('slow'));

      final result = await repository.getData('w1', DateTime(2026, 10));

      expect(result, const Left<Failure, TaxReserveData>(NetworkFailure('network_error')));
    });

    test('an unexpected error becomes a failure instead of escaping', () async {
      when(() => remote.getData(any(), any())).thenThrow(StateError('boom'));

      final result = await repository.getData('w1', DateTime(2026, 10));

      expect(result, const Left<Failure, TaxReserveData>(ServerFailure('unknown_error')));
    });

    test('a column that is not what it should be becomes a failure instead of escaping', () async {
      when(() => remote.getData(any(), any())).thenAnswer((_) async => throw const FormatException('not a number'));

      final result = await repository.getData('w1', DateTime(2026, 10));

      expect(result.isLeft(), isTrue);
    });
  });

  group('savePercent', () {
    test('succeeds when the data source does', () async {
      when(() => remote.savePercent('w1', 650)).thenAnswer((_) async {});

      final result = await repository.savePercent('w1', 650);

      expect(result.isRight(), isTrue);
      verify(() => remote.savePercent('w1', 650)).called(1);
    });

    test('a personal workspace refused by the database becomes a RuleFailure', () async {
      when(() => remote.savePercent(any(), any())).thenThrow(
        PostgrestException(message: 'violates check constraint', code: '23514'),
      );

      final result = await repository.savePercent('w1', 650);

      expect(result, const Left<Failure, void>(RuleFailure('violates check constraint')));
    });

    test("someone else's workspace becomes PermissionFailure", () async {
      when(() => remote.savePercent(any(), any()))
          .thenThrow(PostgrestException(message: 'forbidden', code: '42501'));

      final result = await repository.savePercent('w1', 650);

      expect(result, const Left<Failure, void>(PermissionFailure('forbidden')));
    });

    test('an unexpected error becomes a failure instead of escaping', () async {
      when(() => remote.savePercent(any(), any())).thenThrow(StateError('boom'));

      final result = await repository.savePercent('w1', 650);

      expect(result, const Left<Failure, void>(ServerFailure('unknown_error')));
    });
  });
}
