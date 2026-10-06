import 'dart:async';

import 'package:finly/core/error/failure.dart';
import 'package:finly/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:finly/features/dashboard/data/models/cash_flow_entry_model.dart';
import 'package:finly/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements DashboardRemoteDataSource {}

void main() {
  late MockRemote remote;
  late DashboardRepositoryImpl repository;

  final month = DateTime(2026, 10);

  setUp(() {
    remote = MockRemote();
    repository = DashboardRepositoryImpl(remote);
  });

  test('getCashFlow returns the entries', () async {
    when(() => remote.getCashFlow('w1', month)).thenAnswer(
      (_) async => const [
        CashFlowEntryModel(
          type: TransactionType.income,
          status: TransactionStatus.posted,
          currency: 'BRL',
          amountCents: 5000,
        ),
      ],
    );

    final result = await repository.getCashFlow('w1', month);

    result.fold(
      (failure) => fail('expected entries, got $failure'),
      (entries) => expect(entries.single.amountCents, 5000),
    );
  });

  test('getUpcoming returns what the data source returns', () async {
    final from = DateTime(2026, 9, 5);
    final to = DateTime(2026, 10, 20);
    when(() => remote.getUpcoming('w1', from: from, to: to))
        .thenAnswer((_) async => []);

    final result = await repository.getUpcoming('w1', from: from, to: to);

    result.fold(
      (failure) => fail('expected a list, got $failure'),
      (items) => expect(items, isEmpty),
    );
  });

  test('another user\'s workspace becomes PermissionFailure', () async {
    when(() => remote.getCashFlow('w1', month)).thenThrow(
      PostgrestException(message: 'forbidden', code: '42501'),
    );

    final result = await repository.getCashFlow('w1', month);

    expect(
      result.isLeft(),
      isTrue,
    );
    result.fold(
      (failure) => expect(failure, const PermissionFailure('forbidden')),
      (_) => fail('expected a failure'),
    );
  });

  test('a timeout becomes NetworkFailure', () async {
    when(() => remote.getCashFlow('w1', month)).thenThrow(TimeoutException('slow'));

    final result = await repository.getCashFlow('w1', month);

    result.fold(
      (failure) => expect(failure, const NetworkFailure('network_error')),
      (_) => fail('expected a failure'),
    );
  });
}