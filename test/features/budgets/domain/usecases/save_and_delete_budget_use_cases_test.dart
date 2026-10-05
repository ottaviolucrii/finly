import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:finly/features/budgets/domain/repositories/budget_repository.dart';
import 'package:finly/features/budgets/domain/usecases/delete_budget_use_case.dart';
import 'package:finly/features/budgets/domain/usecases/save_budget_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBudgetRepository extends Mock implements BudgetRepository {}

void main() {
  late MockBudgetRepository repository;

  final saved = BudgetEntity(
    id: 'b1',
    workspaceId: 'w1',
    categoryId: 'c1',
    effectiveFrom: DateTime(2026, 3),
    limitCents: 80000,
    currency: 'BRL',
  );

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() => repository = MockBudgetRepository());

  group('SaveBudgetUseCase', () {
    SaveBudgetParams params({
      String categoryId = 'c1',
      int limitCents = 80000,
      String currency = 'BRL',
    }) {
      return SaveBudgetParams(
        workspaceId: 'w1',
        categoryId: categoryId,
        month: DateTime(2026, 3, 17),
        limitCents: limitCents,
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

    Future<void> expectRejected(SaveBudgetParams p, String code) async {
      final result = await SaveBudgetUseCase(repository)(p);
      expect(result, Left<Failure, BudgetEntity>(ValidationFailure(code)));
      verifyRepositoryNotCalled();
    }

    test('rejects a missing category', () async {
      await expectRejected(params(categoryId: ' '), 'invalid_category');
    });

    test('rejects a zero or negative limit', () async {
      await expectRejected(params(limitCents: 0), 'invalid_limit');
      await expectRejected(params(limitCents: -5), 'invalid_limit');
    });

    test('rejects an unsupported currency', () async {
      await expectRejected(params(currency: 'GBP'), 'invalid_currency');
    });

    test('saves from the first day of the chosen month', () async {
      when(() => repository.saveBudget(
            workspaceId: 'w1',
            categoryId: 'c1',
            effectiveFrom: DateTime(2026, 3),
            limitCents: 80000,
            currency: 'BRL',
          )).thenAnswer((_) async => Right<Failure, BudgetEntity>(saved));

      final result = await SaveBudgetUseCase(repository)(params());

      expect(result, Right<Failure, BudgetEntity>(saved));
    });

    test('passes a repository failure through unchanged', () async {
      when(() => repository.saveBudget(
            workspaceId: any(named: 'workspaceId'),
            categoryId: any(named: 'categoryId'),
            effectiveFrom: any(named: 'effectiveFrom'),
            limitCents: any(named: 'limitCents'),
            currency: any(named: 'currency'),
          )).thenAnswer(
        (_) async => const Left<Failure, BudgetEntity>(
          PermissionFailure('forbidden'),
        ),
      );

      final result = await SaveBudgetUseCase(repository)(params());

      expect(
        result,
        const Left<Failure, BudgetEntity>(PermissionFailure('forbidden')),
      );
    });
  });

  group('DeleteBudgetUseCase', () {
    test('rejects an empty id without calling the repository', () async {
      final result = await DeleteBudgetUseCase(repository)(' ');

      expect(
        result,
        const Left<Failure, void>(ValidationFailure('invalid_budget')),
      );
      verifyNever(() => repository.deleteBudget(any()));
    });

    test('deletes the budget', () async {
      when(() => repository.deleteBudget('b1'))
          .thenAnswer((_) async => const Right<Failure, void>(null));

      final result = await DeleteBudgetUseCase(repository)('b1');

      expect(result.isRight(), isTrue);
      verify(() => repository.deleteBudget('b1')).called(1);
    });
  });
}