import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/recurring/data/datasources/recurring_remote_data_source.dart';
import 'package:finly/features/recurring/data/models/recurring_model.dart';
import 'package:finly/features/recurring/data/repositories/recurring_repository_impl.dart';
import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:finly/features/recurring/domain/entities/recurring_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements RecurringRemoteDataSource {}

void main() {
  late MockRemote remote;
  late RecurringRepositoryImpl repository;

  final model = RecurringModel(
    id: 'r1',
    workspaceId: 'w1',
    accountId: 'a1',
    categoryId: null,
    type: TransactionType.expense,
    amountCents: 120000,
    currency: 'BRL',
    description: 'Aluguel',
    frequency: RecurrenceFrequency.monthly,
    intervalCount: 1,
    startDate: DateTime(2026, 3, 5),
    endDate: null,
    isActive: true,
  );

  setUpAll(() {
    registerFallbackValue(TransactionType.expense);
    registerFallbackValue(RecurrenceFrequency.monthly);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    remote = MockRemote();
    repository = RecurringRepositoryImpl(remote);
  });

  Future<Either<Failure, RecurringEntity>> create() {
    return repository.createRecurring(
      workspaceId: 'w1',
      accountId: 'a1',
      type: TransactionType.expense,
      amountCents: 120000,
      currency: 'BRL',
      description: 'Aluguel',
      frequency: RecurrenceFrequency.monthly,
      intervalCount: 1,
      startDate: DateTime(2026, 3, 5),
    );
  }

  void stubCreate(Future<RecurringModel> Function() answer) {
    when(() => remote.createRecurring(
          workspaceId: any(named: 'workspaceId'),
          accountId: any(named: 'accountId'),
          categoryId: any(named: 'categoryId'),
          type: any(named: 'type'),
          amountCents: any(named: 'amountCents'),
          currency: any(named: 'currency'),
          description: any(named: 'description'),
          frequency: any(named: 'frequency'),
          intervalCount: any(named: 'intervalCount'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        )).thenAnswer((_) => answer());
  }

  test('getRecurring returns the items', () async {
    when(() => remote.getRecurring('w1')).thenAnswer((_) async => [model]);

    final result = await repository.getRecurring('w1');

    result.fold(
      (failure) => fail('expected items, got $failure'),
      (items) => expect(items, <RecurringEntity>[model]),
    );
  });

  test('createRecurring returns the created item', () async {
    stubCreate(() async => model);

    expect(await create(), Right<Failure, RecurringEntity>(model));
  });

  test('a value the database refuses becomes RuleFailure', () async {
    when(() => remote.createRecurring(
          workspaceId: any(named: 'workspaceId'),
          accountId: any(named: 'accountId'),
          categoryId: any(named: 'categoryId'),
          type: any(named: 'type'),
          amountCents: any(named: 'amountCents'),
          currency: any(named: 'currency'),
          description: any(named: 'description'),
          frequency: any(named: 'frequency'),
          intervalCount: any(named: 'intervalCount'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
        )).thenThrow(
      PostgrestException(
        message: 'violates check constraint',
        code: '23514',
      ),
    );

    final result = await create();

    expect(result.isLeft(), isTrue);
  });

  test('setActive succeeds', () async {
    when(() => remote.setActive('r1', active: false)).thenAnswer((_) async {});

    final result = await repository.setActive('r1', active: false);

    expect(result.isRight(), isTrue);
    verify(() => remote.setActive('r1', active: false)).called(1);
  });

  test('generateDue returns how many occurrences were created', () async {
    when(() => remote.generateDue()).thenAnswer((_) async => 4);

    final result = await repository.generateDue();

    expect(result, const Right<Failure, int>(4));
  });

  test('another user\'s item becomes PermissionFailure', () async {
    when(() => remote.setActive('r1', active: true)).thenThrow(
      PostgrestException(message: 'forbidden', code: '42501'),
    );

    final result = await repository.setActive('r1', active: true);

    expect(
      result,
      const Left<Failure, void>(PermissionFailure('forbidden')),
    );
  });

  test('a timeout becomes NetworkFailure', () async {
    when(() => remote.getRecurring('w1')).thenThrow(TimeoutException('slow'));

    final result = await repository.getRecurring('w1');

    result.fold(
      (failure) => expect(failure, const NetworkFailure('network_error')),
      (_) => fail('expected a failure'),
    );
  });
}