import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/data/datasources/transaction_remote_data_source.dart';
import 'package:finly/features/transactions/data/models/transaction_model.dart';
import 'package:finly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
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
    amountCents: 3000,
    currency: 'BRL',
    description: 'Mercado',
    occurredAt: occurredAt,
  );

  setUpAll(() {
    registerFallbackValue(TransactionStatus.posted);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    remote = MockRemote();
    repository = TransactionRepositoryImpl(remote);
  });

  Future<Either<Failure, TransactionEntity>> update() {
    return repository.updateTransaction(
      transactionId: 't1',
      categoryId: 'c1',
      amountCents: 3000,
      description: 'Mercado',
      occurredAt: occurredAt,
      status: TransactionStatus.posted,
    );
  }

  void stubUpdate(Future<TransactionModel> Function() answer) {
    when(() => remote.updateTransaction(
          transactionId: any(named: 'transactionId'),
          categoryId: any(named: 'categoryId'),
          amountCents: any(named: 'amountCents'),
          description: any(named: 'description'),
          occurredAt: any(named: 'occurredAt'),
          status: any(named: 'status'),
        )).thenAnswer((_) => answer());
  }

  test('updateTransaction returns the updated transaction', () async {
    stubUpdate(() async => model);

    expect(await update(), Right<Failure, TransactionEntity>(model));
  });

  test('a purchase on a paid invoice becomes RuleFailure', () async {
    when(() => remote.updateTransaction(
          transactionId: any(named: 'transactionId'),
          categoryId: any(named: 'categoryId'),
          amountCents: any(named: 'amountCents'),
          description: any(named: 'description'),
          occurredAt: any(named: 'occurredAt'),
          status: any(named: 'status'),
        )).thenThrow(
      PostgrestException(
        message: 'invoice already paid: its transactions are locked',
        code: '23514',
      ),
    );

    expect(
      await update(),
      const Left<Failure, TransactionEntity>(
        RuleFailure('invoice already paid: its transactions are locked'),
      ),
    );
  });

  test('a timeout becomes NetworkFailure', () async {
    when(() => remote.updateTransaction(
          transactionId: any(named: 'transactionId'),
          categoryId: any(named: 'categoryId'),
          amountCents: any(named: 'amountCents'),
          description: any(named: 'description'),
          occurredAt: any(named: 'occurredAt'),
          status: any(named: 'status'),
        )).thenThrow(TimeoutException('slow'));

    final result = await update();

    result.fold(
      (failure) => expect(failure, const NetworkFailure('network_error')),
      (_) => fail('expected a failure'),
    );
  });
}