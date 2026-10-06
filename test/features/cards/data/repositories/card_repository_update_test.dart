import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/data/datasources/card_remote_data_source.dart';
import 'package:finly/features/cards/data/repositories/card_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements CardRemoteDataSource {}

void main() {
  late MockRemote remote;
  late CardRepositoryImpl repository;

  setUp(() {
    remote = MockRemote();
    repository = CardRepositoryImpl(remote);
  });

  Future<Either<Failure, void>> update() {
    return repository.updateCard(
      accountId: 'a1',
      name: 'Nubank',
      limitCents: 800000,
      closingDay: 10,
      dueDay: 17,
    );
  }

  void stubUpdate(Future<void> Function() answer) {
    when(() => remote.updateCard(
          accountId: any(named: 'accountId'),
          name: any(named: 'name'),
          limitCents: any(named: 'limitCents'),
          closingDay: any(named: 'closingDay'),
          dueDay: any(named: 'dueDay'),
        )).thenAnswer((_) => answer());
  }

  test('updateCard succeeds', () async {
    stubUpdate(() async {});

    final result = await update();

    expect(result.isRight(), isTrue);
    verify(() => remote.updateCard(
          accountId: 'a1',
          name: 'Nubank',
          limitCents: 800000,
          closingDay: 10,
          dueDay: 17,
        )).called(1);
  });

  test('renaming to a name already in use becomes ConflictFailure', () async {
    when(() => remote.updateCard(
          accountId: any(named: 'accountId'),
          name: any(named: 'name'),
          limitCents: any(named: 'limitCents'),
          closingDay: any(named: 'closingDay'),
          dueDay: any(named: 'dueDay'),
        )).thenThrow(
      PostgrestException(message: 'duplicate key value', code: '23505'),
    );

    expect(
      await update(),
      const Left<Failure, void>(ConflictFailure('already_exists')),
    );
  });

  test('a value the database refuses becomes RuleFailure', () async {
    when(() => remote.updateCard(
          accountId: any(named: 'accountId'),
          name: any(named: 'name'),
          limitCents: any(named: 'limitCents'),
          closingDay: any(named: 'closingDay'),
          dueDay: any(named: 'dueDay'),
        )).thenThrow(
      PostgrestException(message: 'violates check constraint', code: '23514'),
    );

    final result = await update();

    expect(result.isLeft(), isTrue);
  });

  test('a timeout becomes NetworkFailure', () async {
    when(() => remote.updateCard(
          accountId: any(named: 'accountId'),
          name: any(named: 'name'),
          limitCents: any(named: 'limitCents'),
          closingDay: any(named: 'closingDay'),
          dueDay: any(named: 'dueDay'),
        )).thenThrow(TimeoutException('slow'));

    expect(
      await update(),
      const Left<Failure, void>(NetworkFailure('network_error')),
    );
  });

  test('an unexpected error becomes a failure instead of escaping', () async {
    when(() => remote.updateCard(
          accountId: any(named: 'accountId'),
          name: any(named: 'name'),
          limitCents: any(named: 'limitCents'),
          closingDay: any(named: 'closingDay'),
          dueDay: any(named: 'dueDay'),
        )).thenThrow(StateError('boom'));

    expect(
      await update(),
      const Left<Failure, void>(ServerFailure('unknown_error')),
    );
  });
}