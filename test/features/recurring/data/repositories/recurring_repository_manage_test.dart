import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/recurring/data/datasources/recurring_remote_data_source.dart';
import 'package:finly/features/recurring/data/repositories/recurring_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements RecurringRemoteDataSource {}

void main() {
  late MockRemote remote;
  late RecurringRepositoryImpl repository;

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    remote = MockRemote();
    repository = RecurringRepositoryImpl(remote);
  });

  Future<Either<Failure, void>> update() {
    return repository.updateRecurring(
      id: 'r1',
      categoryId: 'c1',
      amountCents: 130000,
      description: 'Aluguel',
    );
  }

  void stubUpdate(Object error) {
    when(() => remote.updateRecurring(
          id: any(named: 'id'),
          categoryId: any(named: 'categoryId'),
          amountCents: any(named: 'amountCents'),
          description: any(named: 'description'),
          endDate: any(named: 'endDate'),
        )).thenThrow(error);
  }

  test('updateRecurring succeeds', () async {
    when(() => remote.updateRecurring(
          id: 'r1',
          categoryId: 'c1',
          amountCents: 130000,
          description: 'Aluguel',
          endDate: null,
        )).thenAnswer((_) async {});

    final result = await update();

    expect(result.isRight(), isTrue);
  });

  test('a category of the wrong type becomes RuleFailure', () async {
    stubUpdate(
      PostgrestException(
        message: 'category kind does not match transaction type',
        code: '23514',
      ),
    );

    expect(
      await update(),
      const Left<Failure, void>(
        RuleFailure('category kind does not match transaction type'),
      ),
    );
  });

  test('a stranger becomes PermissionFailure', () async {
    stubUpdate(PostgrestException(message: 'forbidden', code: '42501'));

    expect(
      await update(),
      const Left<Failure, void>(PermissionFailure('forbidden')),
    );
  });

  test('deleteRecurring succeeds', () async {
    when(() => remote.deleteRecurring('r1')).thenAnswer((_) async {});

    final result = await repository.deleteRecurring('r1');

    expect(result.isRight(), isTrue);
    verify(() => remote.deleteRecurring('r1')).called(1);
  });

  test('deleteRecurring by a stranger becomes PermissionFailure', () async {
    when(() => remote.deleteRecurring(any()))
        .thenThrow(PostgrestException(message: 'forbidden', code: '42501'));

    final result = await repository.deleteRecurring('r1');

    expect(
      result,
      const Left<Failure, void>(PermissionFailure('forbidden')),
    );
  });

  test('a timeout becomes NetworkFailure', () async {
    when(() => remote.deleteRecurring(any())).thenThrow(TimeoutException('slow'));

    final result = await repository.deleteRecurring('r1');

    expect(
      result,
      const Left<Failure, void>(NetworkFailure('network_error')),
    );
  });

  test('an unexpected error becomes a failure instead of escaping', () async {
    stubUpdate(StateError('boom'));

    expect(
      await update(),
      const Left<Failure, void>(ServerFailure('unknown_error')),
    );
  });
}