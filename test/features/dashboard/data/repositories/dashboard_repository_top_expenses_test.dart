import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:finly/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:finly/features/transactions/data/models/transaction_model.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRemote extends Mock implements DashboardRemoteDataSource {}

void main() {
  late MockRemote remote;
  late DashboardRepositoryImpl repository;

  final from = DateTime(2026, 10);
  final to = DateTime(2026, 11);

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    remote = MockRemote();
    repository = DashboardRepositoryImpl(remote);
  });

  Future<Either<Failure, List<TransactionEntity>>> top() {
    return repository.getTopExpenses(
      'w1',
      from: from,
      to: to,
      currency: 'BRL',
      limit: 5,
    );
  }

  test('returns the biggest expenses from the data source', () async {
    final model = TransactionModel(
      id: 't1',
      workspaceId: 'w1',
      accountId: 'a1',
      categoryId: null,
      type: TransactionType.expense,
      status: TransactionStatus.posted,
      amountCents: 300000,
      currency: 'BRL',
      description: 'Aluguel',
      occurredAt: DateTime(2026, 10, 5),
    );
    when(
      () => remote.getTopExpenses(
        'w1',
        from: from,
        to: to,
        currency: 'BRL',
        limit: 5,
      ),
    ).thenAnswer((_) async => [model]);

    final result = await top();

    result.fold(
      (failure) => fail('expected expenses, got $failure'),
      (expenses) => expect(expenses, <TransactionEntity>[model]),
    );
  });

  test('a timeout becomes NetworkFailure', () async {
    when(
      () => remote.getTopExpenses(
        any(),
        from: any(named: 'from'),
        to: any(named: 'to'),
        currency: any(named: 'currency'),
        limit: any(named: 'limit'),
      ),
    ).thenThrow(TimeoutException('slow'));

    expect(
      await top(),
      const Left<Failure, List<TransactionEntity>>(
        NetworkFailure('network_error'),
      ),
    );
  });

  test('an unexpected error becomes a failure instead of escaping', () async {
    when(
      () => remote.getTopExpenses(
        any(),
        from: any(named: 'from'),
        to: any(named: 'to'),
        currency: any(named: 'currency'),
        limit: any(named: 'limit'),
      ),
    ).thenThrow(StateError('boom'));

    expect(
      await top(),
      const Left<Failure, List<TransactionEntity>>(
        ServerFailure('unknown_error'),
      ),
    );
  });
}
