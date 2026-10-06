import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/domain/repositories/category_repository.dart';
import 'package:finly/features/dashboard/domain/entities/category_spend_entry.dart';
import 'package:finly/features/dashboard/domain/entities/monthly_flow_entry.dart';
import 'package:finly/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:finly/features/reports/domain/entities/monthly_report.dart';
import 'package:finly/features/reports/domain/usecases/get_monthly_report_use_case.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDashboardRepository extends Mock implements DashboardRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

void main() {
  late MockDashboardRepository dashboard;
  late MockCategoryRepository categories;
  late GetMonthlyReportUseCase useCase;

  final october = DateTime(2026, 10, 15, 9);

  const food = CategoryEntity(
    id: 'c1',
    workspaceId: 'w1',
    name: 'Alimentação',
    kind: CategoryKind.expense,
    icon: 'restaurant',
    colorHex: '#F29D38',
    isDefault: true,
  );

  final rent = TransactionEntity(
    id: 't1',
    workspaceId: 'w1',
    accountId: 'a1',
    categoryId: 'c1',
    type: TransactionType.expense,
    status: TransactionStatus.posted,
    amountCents: 300000,
    currency: 'BRL',
    description: 'Aluguel',
    occurredAt: DateTime(2026, 10, 5),
  );

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    dashboard = MockDashboardRepository();
    categories = MockCategoryRepository();
    useCase = GetMonthlyReportUseCase(dashboard, categories);

    when(() => categories.getAllCategories('w1')).thenAnswer(
      (_) async => const Right<Failure, List<CategoryEntity>>([food]),
    );
  });

  void stubFlow(List<MonthlyFlowEntry> entries) {
    when(() => dashboard.getMonthlyFlow(
          'w1',
          from: DateTime(2026, 9),
          to: DateTime(2026, 11),
        )).thenAnswer(
      (_) async => Right<Failure, List<MonthlyFlowEntry>>(entries),
    );
  }

  void stubSpend(DateTime month, List<CategorySpendEntry> entries) {
    when(() => dashboard.getCategorySpend('w1', month)).thenAnswer(
      (_) async => Right<Failure, List<CategorySpendEntry>>(entries),
    );
  }

  void stubTop(String currency, List<TransactionEntity> list) {
    when(() => dashboard.getTopExpenses(
          'w1',
          from: DateTime(2026, 10),
          to: DateTime(2026, 11),
          currency: currency,
          limit: 5,
        )).thenAnswer(
      (_) async => Right<Failure, List<TransactionEntity>>(list),
    );
  }

  GetMonthlyReportParams reportParams() => GetMonthlyReportParams(
        workspaceId: 'w1',
        month: october,
      );

  test('rejects an empty workspace id', () async {
    final result = await useCase(
      GetMonthlyReportParams(workspaceId: ' ', month: october),
    );

    expect(
      result,
      const Left<Failure, MonthlyReport>(ValidationFailure('invalid_workspace')),
    );
  });

  test('asks for this month and the one before', () async {
    stubFlow(const []);
    stubSpend(DateTime(2026, 10), const []);
    stubSpend(DateTime(2026, 9), const []);

    await useCase(reportParams());

    verify(() => dashboard.getMonthlyFlow(
          'w1',
          from: DateTime(2026, 9),
          to: DateTime(2026, 11),
        )).called(1);
    verify(() => dashboard.getCategorySpend('w1', DateTime(2026, 10))).called(1);
    verify(() => dashboard.getCategorySpend('w1', DateTime(2026, 9))).called(1);
  });

  test('builds the report of a currency with the previous month beside it', () async {
    stubFlow([
      MonthlyFlowEntry(
        month: DateTime(2026, 10),
        currency: 'BRL',
        incomeCents: 500000,
        expenseCents: 300000,
      ),
      MonthlyFlowEntry(
        month: DateTime(2026, 9),
        currency: 'BRL',
        incomeCents: 400000,
        expenseCents: 350000,
      ),
    ]);
    stubSpend(DateTime(2026, 10), const [
      CategorySpendEntry(categoryId: 'c1', currency: 'BRL', spentCents: 300000),
    ]);
    stubSpend(DateTime(2026, 9), const [
      CategorySpendEntry(categoryId: 'c1', currency: 'BRL', spentCents: 250000),
    ]);
    stubTop('BRL', [rent]);

    final result = await useCase(reportParams());

    result.fold(
      (failure) => fail('expected a report, got $failure'),
      (report) {
        expect(report.month, DateTime(2026, 10));
        final brl = report.byCurrency.single;
        expect(brl.currency, 'BRL');
        expect(brl.incomeCents, 500000);
        expect(brl.expenseCents, 300000);
        expect(brl.netCents, 200000);
        expect(brl.previousIncomeCents, 400000);
        expect(brl.previousExpenseCents, 350000);
        expect(brl.previousNetCents, 50000);
        expect(brl.categories.single.name, 'Alimentação');
        expect(brl.categories.single.previousCents, 250000);
        expect(brl.topExpenses, [rent]);
      },
    );
  });

  test('lists the currencies that have something this month, BRL first', () async {
    stubFlow([
      MonthlyFlowEntry(
        month: DateTime(2026, 10),
        currency: 'USD',
        incomeCents: 0,
        expenseCents: 5000,
      ),
      MonthlyFlowEntry(
        month: DateTime(2026, 10),
        currency: 'BRL',
        incomeCents: 100,
        expenseCents: 0,
      ),
      // Only in the month before: not listed.
      MonthlyFlowEntry(
        month: DateTime(2026, 9),
        currency: 'EUR',
        incomeCents: 100,
        expenseCents: 100,
      ),
    ]);
    stubSpend(DateTime(2026, 10), const []);
    stubSpend(DateTime(2026, 9), const []);
    stubTop('BRL', const []);
    stubTop('USD', const []);

    final result = await useCase(reportParams());

    result.fold(
      (failure) => fail('expected a report, got $failure'),
      (report) => expect(report.byCurrency.map((c) => c.currency), ['BRL', 'USD']),
    );
  });

  test('is empty when nothing happened', () async {
    stubFlow(const []);
    stubSpend(DateTime(2026, 10), const []);
    stubSpend(DateTime(2026, 9), const []);

    final result = await useCase(reportParams());

    result.fold(
      (failure) => fail('expected a report, got $failure'),
      (report) => expect(report.isEmpty, isTrue),
    );
  });

  test('fails when a load fails', () async {
    stubFlow(const []);
    stubSpend(DateTime(2026, 9), const []);
    when(() => dashboard.getCategorySpend('w1', DateTime(2026, 10))).thenAnswer(
      (_) async => const Left<Failure, List<CategorySpendEntry>>(
        NetworkFailure('network_error'),
      ),
    );

    final result = await useCase(reportParams());

    expect(
      result,
      const Left<Failure, MonthlyReport>(NetworkFailure('network_error')),
    );
  });

  test('fails when the biggest expenses fail to load', () async {
    stubFlow([
      MonthlyFlowEntry(
        month: DateTime(2026, 10),
        currency: 'BRL',
        incomeCents: 100,
        expenseCents: 0,
      ),
    ]);
    stubSpend(DateTime(2026, 10), const []);
    stubSpend(DateTime(2026, 9), const []);
    when(() => dashboard.getTopExpenses(
          'w1',
          from: any(named: 'from'),
          to: any(named: 'to'),
          currency: any(named: 'currency'),
          limit: any(named: 'limit'),
        )).thenAnswer(
      (_) async => const Left<Failure, List<TransactionEntity>>(
        ServerFailure('unknown_error'),
      ),
    );

    final result = await useCase(reportParams());

    expect(
      result,
      const Left<Failure, MonthlyReport>(ServerFailure('unknown_error')),
    );
  });
}