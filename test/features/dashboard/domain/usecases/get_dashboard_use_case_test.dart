import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/repositories/account_repository.dart';
import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:finly/features/budgets/domain/entities/budget_overview.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/budgets/domain/usecases/get_budget_overview_use_case.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/dashboard/domain/entities/cash_flow_entry.dart';
import 'package:finly/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:finly/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:finly/features/dashboard/domain/usecases/get_dashboard_use_case.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAccountRepository extends Mock implements AccountRepository {}

class MockDashboardRepository extends Mock implements DashboardRepository {}

class MockGetOverview extends Mock implements GetBudgetOverviewUseCase {}

void main() {
  late MockAccountRepository accounts;
  late MockDashboardRepository dashboard;
  late MockGetOverview overview;
  late GetDashboardUseCase useCase;

  // Any time of the day works: 5 October 2026.
  final today = DateTime(2026, 10, 5, 14, 30);
  final month = DateTime(2026, 10);

  const checking = AccountEntity(
    id: 'a1',
    workspaceId: 'w1',
    name: 'Conta corrente',
    type: AccountType.checking,
    currency: 'BRL',
    openingBalanceCents: 100000,
    postedBalanceCents: 100000,
    projectedBalanceCents: 90000,
  );

  BudgetProgress progress(String name, int limit, int spent) {
    return BudgetProgress(
      budget: BudgetEntity(
        id: 'b-$name',
        workspaceId: 'w1',
        categoryId: 'c-$name',
        effectiveFrom: month,
        limitCents: limit,
        currency: 'BRL',
      ),
      category: CategoryEntity(
        id: 'c-$name',
        workspaceId: 'w1',
        name: name,
        kind: CategoryKind.expense,
        icon: 'category',
        colorHex: '#A8A8A8',
        isDefault: true,
      ),
      spentCents: spent,
    );
  }

  TransactionEntity pending(String id, DateTime when) {
    return TransactionEntity(
      id: id,
      workspaceId: 'w1',
      accountId: 'a1',
      categoryId: null,
      type: TransactionType.expense,
      status: TransactionStatus.pending,
      amountCents: 1000,
      currency: 'BRL',
      description: id,
      occurredAt: when,
    );
  }

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(
      GetBudgetOverviewParams(workspaceId: 'w', month: DateTime(2026)),
    );
  });

  setUp(() {
    accounts = MockAccountRepository();
    dashboard = MockDashboardRepository();
    overview = MockGetOverview();
    useCase = GetDashboardUseCase(accounts, dashboard, overview);

    when(() => accounts.getAccounts('w1')).thenAnswer(
      (_) async => const Right<Failure, List<AccountEntity>>([checking]),
    );
    when(() => dashboard.getCashFlow('w1', month)).thenAnswer(
      (_) async => const Right<Failure, List<CashFlowEntry>>([]),
    );
    when(() => dashboard.getUpcoming(
          'w1',
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer(
      (_) async => const Right<Failure, List<TransactionEntity>>([]),
    );
    when(() => overview(any())).thenAnswer(
      (_) async => Right<Failure, BudgetOverview>(
        BudgetOverview(
          month: month,
          items: const [],
          expenseCategories: const [],
          withoutBudget: const [],
        ),
      ),
    );
  });

  GetDashboardParams params() =>
      GetDashboardParams(workspaceId: 'w1', today: today);

  Future<DashboardData> load() async {
    final result = await useCase(params());
    return result.fold(
      (failure) => fail('expected data, got $failure'),
      (data) => data,
    );
  }

  test('rejects an empty workspace id', () async {
    final result = await useCase(
      GetDashboardParams(workspaceId: ' ', today: today),
    );

    expect(
      result,
      const Left<Failure, DashboardData>(ValidationFailure('invalid_workspace')),
    );
  });

  test('puts balances, month, budgets and upcoming items together', () async {
    when(() => overview(any())).thenAnswer(
      (_) async => Right<Failure, BudgetOverview>(
        BudgetOverview(
          month: month,
          items: [
            progress('a', 1000, 1200),
            progress('b', 1000, 900),
            progress('c', 1000, 500),
            progress('d', 1000, 100),
          ],
          expenseCategories: const [],
          withoutBudget: const [],
        ),
      ),
    );

    final data = await load();

    expect(data.month, month);
    expect(data.accountCount, 1);
    expect(data.hasAccounts, isTrue);
    expect(data.balances.single.postedCents, 100000);
    expect(data.balances.single.projectedCents, 90000);
    // Only the three budgets closest to their limit.
    expect(data.budgets.map((b) => b.category.name), ['a', 'b', 'c']);
  });

  test('asks for the month of today and for the pending window', () async {
    await load();

    verify(() => dashboard.getCashFlow('w1', month)).called(1);
    // 30 days back (overdue items) up to and including 14 days ahead.
    verify(() => dashboard.getUpcoming(
          'w1',
          from: DateTime(2026, 9, 5),
          to: DateTime(2026, 10, 20),
        )).called(1);
    verify(
      () => overview(GetBudgetOverviewParams(workspaceId: 'w1', month: month)),
    ).called(1);
  });

  test('upcoming items come oldest first and at most six', () async {
    when(() => dashboard.getUpcoming(
          'w1',
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer(
      (_) async => Right<Failure, List<TransactionEntity>>([
        for (var day = 12; day >= 1; day--) pending('d$day', DateTime(2026, 10, day)),
      ]),
    );

    final data = await load();

    expect(data.upcoming, hasLength(6));
    expect(
      data.upcoming.map((t) => t.id),
      ['d1', 'd2', 'd3', 'd4', 'd5', 'd6'],
    );
  });

  test('no accounts is reported, not hidden', () async {
    when(() => accounts.getAccounts('w1')).thenAnswer(
      (_) async => const Right<Failure, List<AccountEntity>>([]),
    );

    final data = await load();

    expect(data.hasAccounts, isFalse);
    expect(data.balances, isEmpty);
  });

  test('a failure in any part fails the whole dashboard', () async {
    when(() => dashboard.getCashFlow('w1', month)).thenAnswer(
      (_) async => const Left<Failure, List<CashFlowEntry>>(
        NetworkFailure('network_error'),
      ),
    );

    final result = await useCase(params());

    expect(
      result,
      const Left<Failure, DashboardData>(NetworkFailure('network_error')),
    );
  });
}