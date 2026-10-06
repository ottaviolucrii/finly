import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:finly/features/dashboard/data/models/category_spend_entry_model.dart';
import 'package:finly/features/dashboard/data/models/monthly_flow_entry_model.dart';
import 'package:finly/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:finly/features/dashboard/domain/entities/category_spend_entry.dart';
import 'package:finly/features/dashboard/domain/entities/monthly_flow_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRemote extends Mock implements DashboardRemoteDataSource {}

void main() {
  late MockRemote remote;
  late DashboardRepositoryImpl repository;

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    remote = MockRemote();
    repository = DashboardRepositoryImpl(remote);
  });

  final from = DateTime(2026, 5);
  final to = DateTime(2026, 11);

  test('getMonthlyFlow returns the months from the data source', () async {
    final model = MonthlyFlowEntryModel(
      month: DateTime(2026, 10),
      currency: 'BRL',
      incomeCents: 200000,
      expenseCents: 460001,
    );
    when(() => remote.getMonthlyFlow('w1', from: from, to: to))
        .thenAnswer((_) async => [model]);

    final result = await repository.getMonthlyFlow('w1', from: from, to: to);

    result.fold(
      (failure) => fail('expected entries, got $failure'),
      (entries) => expect(entries, <MonthlyFlowEntry>[model]),
    );
  });

  test('getCategorySpend returns the spending from the data source', () async {
    const model = CategorySpendEntryModel(
      categoryId: 'c1',
      currency: 'BRL',
      spentCents: 9000,
    );
    when(() => remote.getCategorySpend('w1', DateTime(2026, 10)))
        .thenAnswer((_) async => [model]);

    final result = await repository.getCategorySpend('w1', DateTime(2026, 10));

    result.fold(
      (failure) => fail('expected entries, got $failure'),
      (entries) => expect(entries, <CategorySpendEntry>[model]),
    );
  });

  test('a timeout becomes NetworkFailure', () async {
    when(() => remote.getMonthlyFlow(any(), from: any(named: 'from'), to: any(named: 'to')))
        .thenThrow(TimeoutException('slow'));

    final result = await repository.getMonthlyFlow('w1', from: from, to: to);

    expect(
      result,
      const Left<Failure, List<MonthlyFlowEntry>>(NetworkFailure('network_error')),
    );
  });

  test('an unexpected error becomes a failure instead of escaping', () async {
    when(() => remote.getCategorySpend(any(), any())).thenThrow(StateError('boom'));

    final result = await repository.getCategorySpend('w1', DateTime(2026, 10));

    expect(
      result,
      const Left<Failure, List<CategorySpendEntry>>(ServerFailure('unknown_error')),
    );
  });
}