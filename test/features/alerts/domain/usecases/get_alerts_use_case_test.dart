import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/alerts/domain/entities/app_alert.dart';
import 'package:finly/features/alerts/domain/usecases/get_alerts_use_case.dart';
import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:finly/features/budgets/domain/entities/budget_overview.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/budgets/domain/usecases/get_budget_overview_use_case.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBudgetOverview extends Mock implements GetBudgetOverviewUseCase {}

class MockDashboardRepository extends Mock implements DashboardRepository {}

void main() {
  late MockBudgetOverview budgets;
  late MockDashboardRepository dashboard;
  late GetAlertsUseCase useCase;

  final today = DateTime(2026, 10, 6, 15);
  final params = GetAlertsParams(workspaceId: 'w1', today: today);

  final food = CategoryEntity(
    id: 'c1',
    workspaceId: 'w1',
    name: 'Alimentação',
    kind: CategoryKind.expense,
    icon: 'restaurant',
    colorHex: '#F29D38',
    isDefault: true,
  );

  BudgetOverview overview(List<BudgetProgress> items) => BudgetOverview(
        month: DateTime(2026, 10),
        items: items,
        expenseCategories: [food],
        withoutBudget: const [],
      );

  BudgetProgress progress(int spent) => BudgetProgress(
        budget: BudgetEntity(
          id: 'b1',
          workspaceId: 'w1',
          categoryId: 'c1',
          effectiveFrom: DateTime(2026, 10),
          limitCents: 100000,
          currency: 'BRL',
        ),
        category: food,
        spentCents: spent,
      );

  TransactionEntity bill(DateTime on, String description) => TransactionEntity(
        id: description,
        workspaceId: 'w1',
        accountId: 'a1',
        categoryId: null,
        type: TransactionType.expense,
        status: TransactionStatus.pending,
        amountCents: 150000,
        currency: 'BRL',
        description: description,
        occurredAt: on,
      );

  void stubOverview(BudgetOverview value) {
    when(() => budgets(GetBudgetOverviewParams(workspaceId: 'w1', month: today)))
        .thenAnswer((_) async => Right<Failure, BudgetOverview>(value));
  }

  void stubUpcoming(List<TransactionEntity> list) {
    when(() => dashboard.getUpcoming(
          'w1',
          from: DateTime(2026, 10, 6 - GetAlertsUseCase.lookBackDays),
          to: DateTime(2026, 10, 10),
        )).thenAnswer(
      (_) async => Right<Failure, List<TransactionEntity>>(list),
    );
  }

  setUpAll(() {
    registerFallbackValue(GetBudgetOverviewParams(workspaceId: 'w', month: DateTime(2026)));
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    budgets = MockBudgetOverview();
    dashboard = MockDashboardRepository();
    useCase = GetAlertsUseCase(budgets, dashboard);
  });

  test('rejects an empty workspace id', () async {
    final result = await useCase(GetAlertsParams(workspaceId: ' ', today: today));

    expect(
      result,
      const Left<Failure, List<AppAlert>>(ValidationFailure('invalid_workspace')),
    );
  });

  test('is empty when nothing needs attention', () async {
    stubOverview(overview([progress(10000)]));
    stubUpcoming(const []);

    final result = await useCase(params);

    result.fold(
      (failure) => fail('expected alerts, got $failure'),
      (alerts) => expect(alerts, isEmpty),
    );
  });

  test('mixes budget and bill alerts, most urgent first', () async {
    stubOverview(overview([progress(95000)]));
    stubUpcoming([
      bill(DateTime(2026, 10, 8), 'Internet'),
      bill(DateTime(2026, 10, 4), 'Aluguel'),
    ]);

    final result = await useCase(params);

    result.fold(
      (failure) => fail('expected alerts, got $failure'),
      (alerts) => expect(
        alerts.map((a) => a.kind),
        [AlertKind.billOverdue, AlertKind.budgetNear, AlertKind.billDueSoon],
      ),
    );
  });

  test('looks 60 days back and 3 days ahead for bills', () async {
    stubOverview(overview(const []));
    stubUpcoming(const []);

    await useCase(params);

    verify(() => dashboard.getUpcoming(
          'w1',
          from: DateTime(2026, 10, 6 - 60),
          to: DateTime(2026, 10, 10),
        )).called(1);
  });

  test('fails when the budgets fail to load', () async {
    when(() => budgets(any())).thenAnswer(
      (_) async => const Left<Failure, BudgetOverview>(NetworkFailure('network_error')),
    );
    stubUpcoming(const []);

    final result = await useCase(params);

    expect(
      result,
      const Left<Failure, List<AppAlert>>(NetworkFailure('network_error')),
    );
  });

  test('fails when the bills fail to load', () async {
    stubOverview(overview(const []));
    when(() => dashboard.getUpcoming(
          any(),
          from: any(named: 'from'),
          to: any(named: 'to'),
        )).thenAnswer(
      (_) async => const Left<Failure, List<TransactionEntity>>(
        ServerFailure('unknown_error'),
      ),
    );

    final result = await useCase(params);

    expect(
      result,
      const Left<Failure, List<AppAlert>>(ServerFailure('unknown_error')),
    );
  });
}