import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/trash/data/datasources/trash_remote_data_source.dart';
import 'package:finly/features/trash/data/models/trashed_transaction_model.dart';
import 'package:finly/features/trash/data/repositories/trash_repository_impl.dart';
import 'package:finly/features/trash/domain/entities/trashed_transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRemote extends Mock implements TrashRemoteDataSource {}

void main() {
  const row = {
    'id': 't1',
    'workspace_id': 'w1',
    'account_id': 'a1',
    'currency': 'BRL',
    'category_id': 'c1',
    'invoice_id': null,
    'recurring_id': null,
    'scheduled_for': null,
    'transfer_id': null,
    'installment_group_id': null,
    'installment_number': null,
    'installment_total': null,
    'type': 'expense',
    'status': 'posted',
    'amount_cents': 2500,
    'description': 'Mercado',
    'notes': null,
    'occurred_at': '2026-10-02T15:00:00+00:00',
    'receipt_path': null,
    'deleted_at': '2026-10-05T22:18:00.863437+00:00',
    'created_at': '2026-10-02T15:00:00+00:00',
    'updated_at': '2026-10-05T22:18:00+00:00',
  };

  group('TrashedTransactionModel', () {
    test('reads the transaction and when it was deleted', () {
      final model = TrashedTransactionModel.fromMap(row);

      expect(model.transaction.id, 't1');
      expect(model.transaction.description, 'Mercado');
      expect(model.transaction.amountCents, 2500);
      expect(
        model.deletedAt.toUtc(),
        DateTime.utc(2026, 10, 5, 22, 18, 0, 863, 437),
      );
    });
  });

  group('TrashRepositoryImpl', () {
    late MockRemote remote;
    late TrashRepositoryImpl repository;

    setUp(() {
      remote = MockRemote();
      repository = TrashRepositoryImpl(remote);
    });

    Future<Either<Failure, List<TrashedTransaction>>> load() =>
        repository.getTrash('w1', limit: 100);

    test('returns the trash from the data source', () async {
      final model = TrashedTransactionModel.fromMap(row);
      when(() => remote.getTrash('w1', limit: 100)).thenAnswer((_) async => [model]);

      final result = await load();

      result.fold(
        (failure) => fail('expected the trash, got $failure'),
        (items) => expect(items, <TrashedTransaction>[model]),
      );
    });

    test('a timeout becomes NetworkFailure', () async {
      when(() => remote.getTrash(any(), limit: any(named: 'limit')))
          .thenThrow(TimeoutException('slow'));

      expect(
        await load(),
        const Left<Failure, List<TrashedTransaction>>(NetworkFailure('network_error')),
      );
    });

    test('an unexpected error becomes a failure instead of escaping', () async {
      when(() => remote.getTrash(any(), limit: any(named: 'limit')))
          .thenThrow(StateError('boom'));

      expect(
        await load(),
        const Left<Failure, List<TrashedTransaction>>(ServerFailure('unknown_error')),
      );
    });
  });
}