import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/data/datasources/transaction_remote_data_source.dart';
import 'package:finly/features/transactions/data/models/transaction_model.dart';
import 'package:finly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_filter.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements TransactionRemoteDataSource {}

void main() {
  late MockRemote remote;
  late TransactionRepositoryImpl repository;

  final occurredAt = DateTime(2026, 10, 2, 12);
  final model = TransactionModel(
    id: 't1',
    workspaceId: 'w1',
    accountId: 'a1',
    categoryId: 'c1',
    type: TransactionType.expense,
    status: TransactionStatus.posted,
    amountCents: 2500,
    currency: 'BRL',
    description: 'Mercado',
    occurredAt: occurredAt,
  );

  setUpAll(() {
    registerFallbackValue(TransactionType.expense);
    registerFallbackValue(TransactionStatus.posted);
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(const TransactionFilter());
  });

  setUp(() {
    remote = MockRemote();
    repository = TransactionRepositoryImpl(remote);
  });

  Future<Either<Failure, TransactionEntity>> create() {
    return repository.createTransaction(
      workspaceId: 'w1',
      accountId: 'a1',
      categoryId: 'c1',
      type: TransactionType.expense,
      status: TransactionStatus.posted,
      amountCents: 2500,
      currency: 'BRL',
      description: 'Mercado',
      occurredAt: occurredAt,
    );
  }

  test('getTransactions returns the transactions', () async {
    when(() => remote.getTransactions(
          'w1',
          limit: 20,
          offset: 0,
          filter: const TransactionFilter(),
        )).thenAnswer((_) async => [model]);

    final result = await repository.getTransactions('w1');

    result.fold(
      (failure) => fail('expected transactions, got $failure'),
      (transactions) => expect(transactions, [model]),
    );
  });

  test('getTransactions passes the page and the filter to the data source',
      () async {
    const filter = TransactionFilter(
      search: 'mercado',
      type: TransactionType.expense,
      accountId: 'a1',
    );
    when(() => remote.getTransactions(
          'w1',
          limit: 20,
          offset: 40,
          filter: filter,
        )).thenAnswer((_) async => []);

    final result = await repository.getTransactions(
      'w1',
      limit: 20,
      offset: 40,
      filter: filter,
    );

    expect(result.isRight(), isTrue);
    verify(() => remote.getTransactions(
          'w1',
          limit: 20,
          offset: 40,
          filter: filter,
        )).called(1);
  });

  test('createTransaction returns the created transaction', () async {
    when(() => remote.createTransaction(
          workspaceId: any(named: 'workspaceId'),
          accountId: any(named: 'accountId'),
          categoryId: any(named: 'categoryId'),
          type: any(named: 'type'),
          status: any(named: 'status'),
          amountCents: any(named: 'amountCents'),
          currency: any(named: 'currency'),
          description: any(named: 'description'),
          occurredAt: any(named: 'occurredAt'),
        )).thenAnswer((_) async => model);

    expect(await create(), Right<Failure, TransactionEntity>(model));
  });

  test('a category that does not fit the type becomes RuleFailure', () async {
    when(() => remote.createTransaction(
          workspaceId: any(named: 'workspaceId'),
          accountId: any(named: 'accountId'),
          categoryId: any(named: 'categoryId'),
          type: any(named: 'type'),
          status: any(named: 'status'),
          amountCents: any(named: 'amountCents'),
          currency: any(named: 'currency'),
          description: any(named: 'description'),
          occurredAt: any(named: 'occurredAt'),
        )).thenThrow(
      PostgrestException(
        message: 'category kind does not match transaction type',
        code: '23514',
      ),
    );

    expect(
      await create(),
      const Left<Failure, TransactionEntity>(
        RuleFailure('category kind does not match transaction type'),
      ),
    );
  });

  test('updateStatus succeeds', () async {
    when(() => remote.updateStatus('t1', TransactionStatus.posted))
        .thenAnswer((_) async {});

    final result =
        await repository.updateStatus('t1', TransactionStatus.posted);

    expect(result.isRight(), isTrue);
  });

  test('an invalid status change becomes RuleFailure', () async {
    when(() => remote.updateStatus('t1', TransactionStatus.failed)).thenThrow(
      PostgrestException(
        message: 'invalid status change: go through pending first',
        code: '23514',
      ),
    );

    final result =
        await repository.updateStatus('t1', TransactionStatus.failed);

    expect(
      result,
      const Left<Failure, void>(
        RuleFailure('invalid status change: go through pending first'),
      ),
    );
  });

  test('deleteTransaction marks it as deleted', () async {
    when(() => remote.setDeleted('t1', deleted: true))
        .thenAnswer((_) async {});

    final result = await repository.deleteTransaction('t1');

    expect(result.isRight(), isTrue);
    verify(() => remote.setDeleted('t1', deleted: true)).called(1);
  });

  test('restoreTransaction clears the deleted mark', () async {
    when(() => remote.setDeleted('t1', deleted: false))
        .thenAnswer((_) async {});

    final result = await repository.restoreTransaction('t1');

    expect(result.isRight(), isTrue);
    verify(() => remote.setDeleted('t1', deleted: false)).called(1);
  });

  test('a timeout becomes NetworkFailure', () async {
    when(() => remote.getTransactions(
          any(),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          filter: any(named: 'filter'),
        )).thenThrow(TimeoutException('slow'));

    final result = await repository.getTransactions('w1');

    expect(
      result,
      const Left<Failure, List<TransactionEntity>>(
        NetworkFailure('network_error'),
      ),
    );
  });
}