import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/trash/data/datasources/trash_remote_data_source.dart';
import 'package:finly/features/trash/data/models/trashed_transaction_model.dart';
import 'package:finly/features/trash/data/models/trashed_transfer_model.dart';
import 'package:finly/features/trash/data/repositories/trash_repository_impl.dart';
import 'package:finly/features/trash/domain/entities/trashed_transaction.dart';
import 'package:finly/features/trash/domain/entities/trashed_transfer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Map<String, dynamic> leg({
    required String id,
    required String? transferId,
    required String type,
    String accountId = 'a1',
    String deletedAt = '2026-10-05T22:18:00+00:00',
    int cents = 50000,
    String currency = 'BRL',
  }) {
    return {
      ...row,
      'id': id,
      'transfer_id': transferId,
      'type': type,
      'account_id': accountId,
      'deleted_at': deletedAt,
      'amount_cents': cents,
      'currency': currency,
      'category_id': null,
      'description': 'Transferência',
    };
  }

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

  group('TrashedTransferModel.fromRows', () {
    test('puts the two legs of a transfer in one entry', () {
      final result = TrashedTransferModel.fromRows([
        leg(id: 'l1', transferId: 'x1', type: 'transfer_out', accountId: 'a1'),
        leg(id: 'l2', transferId: 'x1', type: 'transfer_in', accountId: 'a2'),
      ]);

      expect(result, hasLength(1));
      expect(result.single.transferId, 'x1');
      expect(result.single.legs, hasLength(2));
      expect(result.single.outLeg?.accountId, 'a1');
      expect(result.single.inLeg?.accountId, 'a2');
    });

    test('a transfer with one leg in this workspace has just that leg', () {
      final result = TrashedTransferModel.fromRows([
        leg(id: 'l1', transferId: 'x1', type: 'transfer_out'),
      ]);

      expect(result.single.legs, hasLength(1));
      expect(result.single.outLeg, isNotNull);
      expect(result.single.inLeg, isNull);
    });

    test('keeps the order in which each transfer first appears', () {
      final result = TrashedTransferModel.fromRows([
        leg(id: 'l1', transferId: 'new', type: 'transfer_out'),
        leg(id: 'l2', transferId: 'old', type: 'transfer_out'),
        leg(id: 'l3', transferId: 'new', type: 'transfer_in'),
        leg(id: 'l4', transferId: 'old', type: 'transfer_in'),
      ]);

      expect(result.map((t) => t.transferId), ['new', 'old']);
      expect(result.first.legs, hasLength(2));
    });

    test('carries the latest deletion time of its legs', () {
      final result = TrashedTransferModel.fromRows([
        leg(
          id: 'l1',
          transferId: 'x1',
          type: 'transfer_out',
          deletedAt: '2026-10-05T22:18:00+00:00',
        ),
        leg(
          id: 'l2',
          transferId: 'x1',
          type: 'transfer_in',
          deletedAt: '2026-10-05T22:18:03+00:00',
        ),
      ]);

      expect(result.single.deletedAt.toUtc(), DateTime.utc(2026, 10, 5, 22, 18, 3));
    });

    test('ignores rows that are not transfer legs', () {
      final result = TrashedTransferModel.fromRows([
        leg(id: 'l1', transferId: null, type: 'expense'),
      ]);

      expect(result, isEmpty);
    });

    test('is empty for no rows', () {
      expect(TrashedTransferModel.fromRows(const []), isEmpty);
    });

    test('keeps the amount and currency of each leg', () {
      final result = TrashedTransferModel.fromRows([
        leg(id: 'l1', transferId: 'x1', type: 'transfer_out', cents: 50000),
        leg(
          id: 'l2',
          transferId: 'x1',
          type: 'transfer_in',
          cents: 9500,
          currency: 'USD',
        ),
      ]);

      expect(result.single.outLeg?.amountCents, 50000);
      expect(result.single.inLeg?.amountCents, 9500);
      expect(result.single.inLeg?.currency, 'USD');
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

    test('getTrashedTransfers returns the transfers from the data source', () async {
      final transfers = TrashedTransferModel.fromRows([
        leg(id: 'l1', transferId: 'x1', type: 'transfer_out'),
        leg(id: 'l2', transferId: 'x1', type: 'transfer_in'),
      ]);
      when(() => remote.getTrashedTransfers('w1', limit: 100))
          .thenAnswer((_) async => transfers);

      final result = await repository.getTrashedTransfers('w1', limit: 100);

      result.fold(
        (failure) => fail('expected transfers, got $failure'),
        (items) => expect(items, <TrashedTransfer>[...transfers]),
      );
    });

    test('restoreTransfer succeeds', () async {
      when(() => remote.restoreTransfer('x1')).thenAnswer((_) async {});

      final result = await repository.restoreTransfer('x1');

      expect(result.isRight(), isTrue);
      verify(() => remote.restoreTransfer('x1')).called(1);
    });

    test('a refused card payment becomes RuleFailure with the reason', () async {
      when(() => remote.restoreTransfer(any())).thenThrow(
        PostgrestException(
          message: 'a card payment cannot be restored: pay the invoice again',
          code: '23514',
        ),
      );

      final result = await repository.restoreTransfer('x1');

      expect(
        result,
        const Left<Failure, void>(
          RuleFailure('a card payment cannot be restored: pay the invoice again'),
        ),
      );
    });

    test('restoring a transfer of someone else becomes PermissionFailure', () async {
      when(() => remote.restoreTransfer(any()))
          .thenThrow(PostgrestException(message: 'forbidden', code: '42501'));

      final result = await repository.restoreTransfer('x1');

      expect(result, const Left<Failure, void>(PermissionFailure('forbidden')));
    });
  });
}