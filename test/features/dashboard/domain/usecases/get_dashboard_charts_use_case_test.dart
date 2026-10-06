import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/domain/repositories/category_repository.dart';
import 'package:finly/features/dashboard/domain/entities/category_spend_entry.dart';
import 'package:finly/features/dashboard/domain/entities/dashboard_charts.dart';
import 'package:finly/features/dashboard/domain/entities/monthly_flow_entry.dart';
import 'package:finly/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:finly/features/dashboard/domain/usecases/get_dashboard_charts_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDashboardRepository extends Mock implements DashboardRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

void main() {
  late MockDashboardRepository dashboard;
  late MockCategoryRepository categories;
  late GetDashboardChartsUseCase useCase;

  final today = DateTime(2026, 10, 6, 14, 30);

  const food = CategoryEntity(
    id: 'c1',
    workspaceId: 'w1',
    name: 'Alimentação',
    kind: CategoryKind.expense,
    icon: 'restaurant',
    colorHex: '#F29D38',
    isDefault: true,
  );

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    dashboard = MockDashboardRepository();
    categories = MockCategoryRepository();
    useCase = GetDashboardChartsUseCase(dashboard, categories);

    when(() => categories.getAllCategories('w1')).thenAnswer(
      (_) async => const Right<Failure, List<CategoryEntity>>([food]),
    );
  });

  void stubFlow(List<MonthlyFlowEntry> entries) {
    when(() => dashboard.getMonthlyFlow(
          'w1',
          from: DateTime(2026, 5),
          to: DateTime(2026, 11),
        )).thenAnswer(
      (_) async => Right<Failure, List<MonthlyFlowEntry>>(entries),
    );
  }

  void stubSpend(List<CategorySpendEntry> entries) {
    when(() => dashboard.getCategorySpend('w1', DateTime(2026, 10))).thenAnswer(
      (_) async => Right<Failure, List<CategorySpendEntry>>(entries),
    );
  }

  test('rejects an empty workspace id', () async {
    final result = await useCase(
      GetDashboardChartsParams(workspaceId: ' ', today: today),
    );

    expect(
      result,
      const Left<Failure, DashboardCharts>(ValidationFailure('invalid_workspace')),
    );
  });

  test('asks for the last six months and this month\'s spending', () async {
    stubFlow(const []);
    stubSpend(const []);

    await useCase(GetDashboardChartsParams(workspaceId: 'w1', today: today));

    verify(() => dashboard.getMonthlyFlow(
          'w1',
          from: DateTime(2026, 5),
          to: DateTime(2026, 11),
        )).called(1);
    verify(() => dashboard.getCategorySpend('w1', DateTime(2026, 10))).called(1);
  });

  test('builds one chart set per currency, BRL first', () async {
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
        incomeCents: 200000,
        expenseCents: 460001,
      ),
    ]);
    stubSpend(const [
      CategorySpendEntry(categoryId: 'c1', currency: 'BRL', spentCents: 9000),
    ]);

    final result = await useCase(
      GetDashboardChartsParams(workspaceId: 'w1', today: today),
    );

    result.fold(
      (failure) => fail('expected charts, got $failure'),
      (charts) {
        expect(charts.month, DateTime(2026, 10));
        expect(charts.byCurrency.map((c) => c.currency), ['BRL', 'USD']);

        final brl = charts.byCurrency.first;
        expect(brl.months, hasLength(6));
        expect(brl.months.last.incomeCents, 200000);
        expect(brl.months.last.expenseCents, 460001);
        expect(brl.categories.single.name, 'Alimentação');
        expect(brl.categories.single.spentCents, 9000);
        expect(brl.hasFlow, isTrue);

        expect(charts.byCurrency.last.categories, isEmpty);
      },
    );
  });

  test('is empty when there is nothing to show', () async {
    stubFlow(const []);
    stubSpend(const []);

    final result = await useCase(
      GetDashboardChartsParams(workspaceId: 'w1', today: today),
    );

    result.fold(
      (failure) => fail('expected charts, got $failure'),
      (charts) => expect(charts.isEmpty, isTrue),
    );
  });

  test('fails when any of the loads fails', () async {
    stubFlow(const []);
    when(() => dashboard.getCategorySpend('w1', DateTime(2026, 10))).thenAnswer(
      (_) async => const Left<Failure, List<CategorySpendEntry>>(
        NetworkFailure('network_error'),
      ),
    );

    final result = await useCase(
      GetDashboardChartsParams(workspaceId: 'w1', today: today),
    );

    expect(
      result,
      const Left<Failure, DashboardCharts>(NetworkFailure('network_error')),
    );
  });
}