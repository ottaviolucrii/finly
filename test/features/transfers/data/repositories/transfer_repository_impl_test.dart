import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transfers/data/datasources/transfer_remote_data_source.dart';
import 'package:finly/features/transfers/data/repositories/transfer_repository_impl.dart';
import 'package:finly/features/transfers/domain/entities/transfer_kind.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements TransferRemoteDataSource {}

void main() {
  late MockRemote remote;
  late TransferRepositoryImpl repository;

  final occurredAt = DateTime(2026, 10, 2, 12);

  setUpAll(() {
    registerFallbackValue(TransferKind.internal);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    remote = MockRemote();
    repository = TransferRepositoryImpl(remote);
  });

  Future<Either<Failure, String>> create() {
    return repository.createTransfer(
      fromAccountId: 'a1',
      toAccountId: 'a2',
      amountCents: 5000,
      description: 'Transferência',
      occurredAt: occurredAt,
      kind: TransferKind.internal,
    );
  }

  void whenCreate(Future<String> Function() answer) {
    when(() => remote.createTransfer(
          fromAccountId: any(named: 'fromAccountId'),
          toAccountId: any(named: 'toAccountId'),
          amountCents: any(named: 'amountCents'),
          toAmountCents: any(named: 'toAmountCents'),
          description: any(named: 'description'),
          occurredAt: any(named: 'occurredAt'),
          kind: any(named: 'kind'),
        )).thenAnswer((_) => answer());
  }

  test('createTransfer returns the transfer id', () async {
    whenCreate(() async => 'tr1');

    expect(await create(), const Right<Failure, String>('tr1'));
  });

  test('a rule refused by the database becomes RuleFailure', () async {
    when(() => remote.createTransfer(
          fromAccountId: any(named: 'fromAccountId'),
          toAccountId: any(named: 'toAccountId'),
          amountCents: any(named: 'amountCents'),
          toAmountCents: any(named: 'toAmountCents'),
          description: any(named: 'description'),
          occurredAt: any(named: 'occurredAt'),
          kind: any(named: 'kind'),
        )).thenThrow(
      PostgrestException(
        message: 'owner withdrawal goes from business to personal',
        code: 'P0001',
      ),
    );

    expect(
      await create(),
      const Left<Failure, String>(
        RuleFailure('owner withdrawal goes from business to personal'),
      ),
    );
  });

  test('an account of another user becomes PermissionFailure', () async {
    when(() => remote.createTransfer(
          fromAccountId: any(named: 'fromAccountId'),
          toAccountId: any(named: 'toAccountId'),
          amountCents: any(named: 'amountCents'),
          toAmountCents: any(named: 'toAmountCents'),
          description: any(named: 'description'),
          occurredAt: any(named: 'occurredAt'),
          kind: any(named: 'kind'),
        )).thenThrow(PostgrestException(message: 'forbidden', code: '42501'));

    expect(
      await create(),
      const Left<Failure, String>(PermissionFailure('forbidden')),
    );
  });

  test('deleteTransfer succeeds', () async {
    when(() => remote.deleteTransfer('tr1')).thenAnswer((_) async {});

    final result = await repository.deleteTransfer('tr1');

    expect(result.isRight(), isTrue);
    verify(() => remote.deleteTransfer('tr1')).called(1);
  });

  test('a timeout becomes NetworkFailure', () async {
    when(() => remote.deleteTransfer('tr1')).thenThrow(TimeoutException('slow'));

    final result = await repository.deleteTransfer('tr1');

    expect(
      result,
      const Left<Failure, void>(NetworkFailure('network_error')),
    );
  });
}