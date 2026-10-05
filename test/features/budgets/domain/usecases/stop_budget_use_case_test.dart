import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:finly/features/budgets/domain/repositories/budget_repository.dart';
import 'package:finly/features/budgets/domain/usecases/stop_budget_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBudgetRepository extends Mock implements BudgetRepository {}

void main() {
  late MockBudgetRepository repository;
  late StopBudgetUseCase useCase;

  final marker = BudgetEntity(
    id: 'b1',
    workspaceId: 'w1',
    categoryId: 'c1',
    effectiveFrom: DateTime(2026, 11),
    limitCents: 0,
    currency: 'BRL',
  );

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    repository = MockBudgetRepository();
    useCase = StopBudgetUseCase(repository);
  });

  StopBudgetParams params({String categoryId = 'c1', String currency = 'BRL'}) {
    return StopBudgetParams(
      workspaceId: 'w1',
      categoryId: categoryId,
      month: DateTime(2026, 11, 17),
      currency: currency,
    );
  }

  void verifyRepositoryNotCalled() {
    verifyNever(() => repository.saveBudget(
          workspaceId: any(named: 'workspaceId'),
          categoryId: any(named: 'categoryId'),
          effectiveFrom: any(named: 'effectiveFrom'),
          limitCents: any(named: 'limitCents'),
          currency: any(named: 'currency'),
        ));
  }

  test('rejects a missing category', () async {
    final result = await useCase(params(categoryId: ' '));

    expect(
      result,
      const Left<Failure, BudgetEntity>(ValidationFailure('invalid_category')),
    );
    verifyRepositoryNotCalled();
  });

  test('rejects an unsupported currency', () async {
    final result = await useCase(params(currency: 'GBP'));

    expect(
      result,
      const Left<Failure, BudgetEntity>(ValidationFailure('invalid_currency')),
    );
    verifyRepositoryNotCalled();
  });

  test('saves an end marker (limit 0) from the first day of the month',
      () async {
    when(() => repository.saveBudget(
          workspaceId: 'w1',
          categoryId: 'c1',
          effectiveFrom: DateTime(2026, 11),
          limitCents: 0,
          currency: 'BRL',
        )).thenAnswer((_) async => Right<Failure, BudgetEntity>(marker));

    final result = await useCase(params());

    expect(result, Right<Failure, BudgetEntity>(marker));
  });

  test('passes a repository failure through unchanged', () async {
    when(() => repository.saveBudget(
          workspaceId: any(named: 'workspaceId'),
          categoryId: any(named: 'categoryId'),
          effectiveFrom: any(named: 'effectiveFrom'),
          limitCents: any(named: 'limitCents'),
          currency: any(named: 'currency'),
        )).thenAnswer(
      (_) async =>
          const Left<Failure, BudgetEntity>(PermissionFailure('forbidden')),
    );

    final result = await useCase(params());

    expect(
      result,
      const Left<Failure, BudgetEntity>(PermissionFailure('forbidden')),
    );
  });
}