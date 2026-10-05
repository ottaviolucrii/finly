import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:finly/features/budgets/domain/entities/budget_overview.dart';
import 'package:finly/features/budgets/domain/entities/category_spend.dart';
import 'package:finly/features/budgets/domain/repositories/budget_repository.dart';
import 'package:finly/features/budgets/domain/usecases/get_budget_overview_use_case.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/domain/repositories/category_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBudgetRepository extends Mock implements BudgetRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

void main() {
  late MockBudgetRepository budgets;
  late MockCategoryRepository categories;
  late GetBudgetOverviewUseCase useCase;

  final march = DateTime(2026, 3);

  CategoryEntity category(String id, String name, CategoryKind kind) {
    return CategoryEntity(
      id: id,
      workspaceId: 'w1',
      name: name,
      kind: kind,
      icon: 'category',
      colorHex: '#A8A8A8',
      isDefault: true,
    );
  }

  final food = category('food', 'Alimentação', CategoryKind.expense);
  final transport = category('transport', 'Transporte', CategoryKind.expense);
  final health = category('health', 'Saúde', CategoryKind.expense);
  final salary = category('salary', 'Salário', CategoryKind.income);

  BudgetEntity budget(String categoryId, DateTime from, int limit,
      {String currency = 'BRL'}) {
    return BudgetEntity(
      id: 'b-$categoryId',
      workspaceId: 'w1',
      categoryId: categoryId,
      effectiveFrom: from,
      limitCents: limit,
      currency: currency,
    );
  }

  void stub({
    List<BudgetEntity> budgetList = const [],
    List<CategorySpend> spend = const [],
    List<CategoryEntity> categoryList = const [],
  }) {
    when(() => budgets.getBudgets('w1')).thenAnswer(
      (_) async => Right<Failure, List<BudgetEntity>>(budgetList),
    );
    when(() => budgets.getMonthlySpend('w1', march)).thenAnswer(
      (_) async => Right<Failure, List<CategorySpend>>(spend),
    );
    when(() => categories.getCategories('w1')).thenAnswer(
      (_) async => Right<Failure, List<CategoryEntity>>(categoryList),
    );
  }

  GetBudgetOverviewParams params([DateTime? month]) =>
      GetBudgetOverviewParams(workspaceId: 'w1', month: month ?? march);

  setUp(() {
    budgets = MockBudgetRepository();
    categories = MockCategoryRepository();
    useCase = GetBudgetOverviewUseCase(budgets, categories);
  });

  Future<BudgetOverview> overview([DateTime? month]) async {
    final result = await useCase(params(month));
    return result.fold(
      (failure) => fail('expected an overview, got $failure'),
      (value) => value,
    );
  }

  test('rejects an empty workspace id', () async {
    final result = await useCase(
      GetBudgetOverviewParams(workspaceId: ' ', month: march),
    );

    expect(
      result,
      const Left<Failure, BudgetOverview>(
        ValidationFailure('invalid_workspace'),
      ),
    );
  });

  test('matches each budget with what was spent in its category', () async {
    stub(
      budgetList: [budget('food', march, 100000)],
      spend: const [
        CategorySpend(categoryId: 'food', currency: 'BRL', spentCents: 25000),
      ],
      categoryList: [food],
    );

    final result = await overview();

    expect(result.items, hasLength(1));
    expect(result.items.single.category, food);
    expect(result.items.single.spentCents, 25000);
    expect(result.items.single.limitCents, 100000);
  });

  test('only the budgets in force that month appear; the others are offered',
      () async {
    stub(
      budgetList: [
        budget('food', march, 100000),
        // Starts in April: not in force in March.
        budget('transport', DateTime(2026, 4), 30000),
      ],
      categoryList: [food, transport, health],
    );

    final result = await overview();

    expect(result.items.map((i) => i.category), [food]);
    expect(result.withoutBudget, [transport, health]);
  });

  test('income categories are never offered for budgets', () async {
    stub(categoryList: [food, salary]);

    final result = await overview();

    expect(result.expenseCategories, [food]);
    expect(result.withoutBudget, [food]);
  });

  test('spending in another currency or without a category is not counted',
      () async {
    stub(
      budgetList: [budget('food', march, 100000)],
      spend: const [
        CategorySpend(categoryId: 'food', currency: 'BRL', spentCents: 10000),
        CategorySpend(categoryId: 'food', currency: 'USD', spentCents: 99999),
        CategorySpend(categoryId: null, currency: 'BRL', spentCents: 88888),
      ],
      categoryList: [food],
    );

    final result = await overview();

    expect(result.items.single.spentCents, 10000);
  });

  test('a budget with no spending shows zero spent', () async {
    stub(budgetList: [budget('food', march, 100000)], categoryList: [food]);

    final result = await overview();

    expect(result.items.single.spentCents, 0);
  });

  test('the most used budget comes first', () async {
    stub(
      budgetList: [
        budget('food', march, 100000),
        budget('transport', march, 10000),
      ],
      spend: const [
        CategorySpend(categoryId: 'food', currency: 'BRL', spentCents: 20000),
        CategorySpend(categoryId: 'transport', currency: 'BRL', spentCents: 9000),
      ],
      categoryList: [food, transport],
    );

    final result = await overview();

    expect(result.items.map((i) => i.category), [transport, food]);
  });

  test('any date inside the month works, and the month is normalised',
      () async {
    stub(categoryList: [food]);

    final result = await overview(DateTime(2026, 3, 17, 9, 30));

    expect(result.month, march);
    verify(() => budgets.getMonthlySpend('w1', march)).called(1);
  });

  test('a failure in any part fails the whole overview', () async {
    when(() => budgets.getBudgets('w1')).thenAnswer(
      (_) async => const Left<Failure, List<BudgetEntity>>(
        NetworkFailure('network_error'),
      ),
    );
    when(() => budgets.getMonthlySpend('w1', march)).thenAnswer(
      (_) async => const Right<Failure, List<CategorySpend>>([]),
    );
    when(() => categories.getCategories('w1')).thenAnswer(
      (_) async => const Right<Failure, List<CategoryEntity>>([]),
    );

    final result = await useCase(params());

    expect(
      result,
      const Left<Failure, BudgetOverview>(NetworkFailure('network_error')),
    );
  });
}