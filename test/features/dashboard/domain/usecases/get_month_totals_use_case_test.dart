import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/dashboard/domain/entities/monthly_flow_entry.dart';
import 'package:finly/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:finly/features/dashboard/domain/usecases/get_month_totals_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDashboardRepository extends Mock implements DashboardRepository {}

void main() {
  late MockDashboardRepository repository;
  late GetMonthTotalsUseCase useCase;

  final october = DateTime(2026, 10);
  final november = DateTime(2026, 11);

  setUp(() {
    repository = MockDashboardRepository();
    useCase = GetMonthTotalsUseCase(repository);
  });

  void stub(Either<Failure, List<MonthlyFlowEntry>> answer) {
    when(() => repository.getMonthlyFlow(any(), from: any(named: 'from'), to: any(named: 'to')))
        .thenAnswer((_) async => answer);
  }

  test('asks for the month only, from its first day to the next month', () async {
    stub(const Right([]));

    await useCase(GetMonthTotalsParams(workspaceId: 'w1', month: DateTime(2026, 10, 17, 22)));

    verify(() => repository.getMonthlyFlow('w1', from: october, to: november)).called(1);
  });

  test('works in December, moving to January of the next year', () async {
    stub(const Right([]));

    await useCase(GetMonthTotalsParams(workspaceId: 'w1', month: DateTime(2026, 12, 5)));

    verify(() => repository.getMonthlyFlow('w1', from: DateTime(2026, 12), to: DateTime(2027, 1))).called(1);
  });

  test('gives the totals of the month, per currency', () async {
    final brl = MonthlyFlowEntry(month: october, currency: 'BRL', incomeCents: 820000, expenseCents: 573190);
    final usd = MonthlyFlowEntry(month: october, currency: 'USD', incomeCents: 0, expenseCents: 1200);
    stub(Right([brl, usd]));

    final result = await useCase(GetMonthTotalsParams(workspaceId: 'w1', month: october));

    expect(result.getOrElse(() => []), [brl, usd]);
  });

  test('drops any row of another month', () async {
    final brl = MonthlyFlowEntry(month: october, currency: 'BRL', incomeCents: 100, expenseCents: 50);
    final other = MonthlyFlowEntry(month: november, currency: 'BRL', incomeCents: 999, expenseCents: 999);
    stub(Right([brl, other]));

    final result = await useCase(GetMonthTotalsParams(workspaceId: 'w1', month: october));

    expect(result.getOrElse(() => []), [brl]);
  });

  test('passes a failure on', () async {
    stub(const Left(NetworkFailure('network_error')));

    final result = await useCase(GetMonthTotalsParams(workspaceId: 'w1', month: october));

    expect(result, const Left<Failure, List<MonthlyFlowEntry>>(NetworkFailure('network_error')));
  });

  test('refuses an empty workspace without asking the database', () async {
    final result = await useCase(GetMonthTotalsParams(workspaceId: '  ', month: october));

    expect(result, const Left<Failure, List<MonthlyFlowEntry>>(ValidationFailure('invalid_workspace')));
    verifyNever(() => repository.getMonthlyFlow(any(), from: any(named: 'from'), to: any(named: 'to')));
  });
}
