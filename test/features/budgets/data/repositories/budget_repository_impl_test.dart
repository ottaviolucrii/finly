import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/budgets/data/datasources/budget_remote_data_source.dart';
import 'package:finly/features/budgets/data/models/budget_model.dart';
import 'package:finly/features/budgets/data/models/category_spend_model.dart';
import 'package:finly/features/budgets/data/repositories/budget_repository_impl.dart';
import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements BudgetRemoteDataSource {}

void main() {
  late MockRemote remote;
  late BudgetRepositoryImpl repository;

  final month = DateTime(2026, 3);
  final model = BudgetModel(
    id: 'b1',
    workspaceId: 'w1',
    categoryId: 'c1',
    effectiveFrom: month,
    limitCents: 80000,
    currency: 'BRL',
  );

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    remote = MockRemote();
    repository = BudgetRepositoryImpl(remote);
  });

  test('getBudgets returns the budgets', () async {
    when(() => remote.getBudgets('w1')).thenAnswer((_) async => [model]);

    final result = await repository.getBudgets('w1');

    result.fold(
      (failure) => fail('expected budgets, got $failure'),
      (budgets) => expect(budgets, <BudgetEntity>[model]),
    );
  });

  test('getMonthlySpend returns the spending', () async {
    when(() => remote.getMonthlySpend('w1', month)).thenAnswer(
      (_) async => const [
        CategorySpendModel(categoryId: 'c1', currency: 'BRL', spentCents: 100),
      ],
    );

    final result = await repository.getMonthlySpend('w1', month);

    result.fold(
      (failure) => fail('expected spending, got $failure'),
      (spend) => expect(spend.single.spentCents, 100),
    );
  });

  test('saveBudget returns the saved budget', () async {
    when(() => remote.saveBudget(
          workspaceId: any(named: 'workspaceId'),
          categoryId: any(named: 'categoryId'),
          effectiveFrom: any(named: 'effectiveFrom'),
          limitCents: any(named: 'limitCents'),
          currency: any(named: 'currency'),
        )).thenAnswer((_) async => model);

    final result = await repository.saveBudget(
      workspaceId: 'w1',
      categoryId: 'c1',
      effectiveFrom: month,
      limitCents: 80000,
      currency: 'BRL',
    );

    expect(result, Right<Failure, BudgetEntity>(model));
  });

  test('a category that is not an expense category becomes RuleFailure',
      () async {
    when(() => remote.saveBudget(
          workspaceId: any(named: 'workspaceId'),
          categoryId: any(named: 'categoryId'),
          effectiveFrom: any(named: 'effectiveFrom'),
          limitCents: any(named: 'limitCents'),
          currency: any(named: 'currency'),
        )).thenThrow(
      PostgrestException(
        message: 'insert violates foreign key constraint',
        code: '23503',
      ),
    );

    final result = await repository.saveBudget(
      workspaceId: 'w1',
      categoryId: 'income-category',
      effectiveFrom: month,
      limitCents: 80000,
      currency: 'BRL',
    );

    expect(result.isLeft(), isTrue);
  });

  test('deleteBudget succeeds', () async {
    when(() => remote.deleteBudget('b1')).thenAnswer((_) async {});

    final result = await repository.deleteBudget('b1');

    expect(result.isRight(), isTrue);
    verify(() => remote.deleteBudget('b1')).called(1);
  });

  test('another user\'s budget becomes PermissionFailure', () async {
    when(() => remote.deleteBudget('b1')).thenThrow(
      PostgrestException(message: 'forbidden', code: '42501'),
    );

    final result = await repository.deleteBudget('b1');

    expect(
      result,
      const Left<Failure, void>(PermissionFailure('forbidden')),
    );
  });

  test('a timeout becomes NetworkFailure', () async {
    when(() => remote.getBudgets('w1')).thenThrow(TimeoutException('slow'));

    final result = await repository.getBudgets('w1');

    result.fold(
      (failure) => expect(failure, const NetworkFailure('network_error')),
      (_) => fail('expected a failure'),
    );
  });
}