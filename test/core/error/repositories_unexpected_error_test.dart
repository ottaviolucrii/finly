import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/budgets/data/datasources/budget_remote_data_source.dart';
import 'package:finly/features/budgets/data/repositories/budget_repository_impl.dart';
import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:finly/features/cards/data/datasources/card_remote_data_source.dart';
import 'package:finly/features/cards/data/repositories/card_repository_impl.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/transactions/data/datasources/transaction_remote_data_source.dart';
import 'package:finly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCardRemote extends Mock implements CardRemoteDataSource {}

class MockTransactionRemote extends Mock implements TransactionRemoteDataSource {}

class MockBudgetRemote extends Mock implements BudgetRemoteDataSource {}

/// Regression tests: an unexpected error (a bug, not a Supabase exception)
/// must come out as a Failure, never escape and leave a screen loading.
void main() {
  setUpAll(() => registerFallbackValue(const TransactionFilter()));

  test('cards: an unexpected error becomes a failure', () async {
    final remote = MockCardRemote();
    when(() => remote.getCards('w1')).thenThrow(StateError('boom'));

    final result = await CardRepositoryImpl(remote).getCards('w1');

    expect(
      result,
      const Left<Failure, List<CreditCardEntity>>(
        ServerFailure('unknown_error'),
      ),
    );
  });

  test('transactions: an unexpected error becomes a failure', () async {
    final remote = MockTransactionRemote();
    when(() => remote.getTransactions(
          any(),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          filter: any(named: 'filter'),
        )).thenThrow(StateError('boom'));

    final result = await TransactionRepositoryImpl(remote).getTransactions('w1');

    expect(
      result,
      const Left<Failure, List<TransactionEntity>>(
        ServerFailure('unknown_error'),
      ),
    );
  });

  test('budgets: an unexpected error becomes a failure', () async {
    final remote = MockBudgetRemote();
    when(() => remote.getBudgets('w1')).thenThrow(StateError('boom'));

    final result = await BudgetRepositoryImpl(remote).getBudgets('w1');

    expect(
      result,
      const Left<Failure, List<BudgetEntity>>(ServerFailure('unknown_error')),
    );
  });
}