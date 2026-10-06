import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/domain/usecases/restore_transaction_use_case.dart';
import 'package:finly/features/trash/domain/entities/trashed_transaction.dart';
import 'package:finly/features/trash/domain/entities/trashed_transfer.dart';
import 'package:finly/features/trash/domain/usecases/get_trash_use_case.dart';
import 'package:finly/features/trash/domain/usecases/get_trashed_transfers_use_case.dart';
import 'package:finly/features/trash/domain/usecases/restore_transfer_use_case.dart';
import 'package:finly/features/trash/presentation/cubit/trash_cubit.dart';
import 'package:finly/features/trash/presentation/cubit/trash_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetTrash extends Mock implements GetTrashUseCase {}

class MockGetTransfers extends Mock implements GetTrashedTransfersUseCase {}

class MockRestore extends Mock implements RestoreTransactionUseCase {}

class MockRestoreTransfer extends Mock implements RestoreTransferUseCase {}

void main() {
  late MockGetTrash getTrash;
  late MockGetTransfers getTransfers;
  late MockRestore restore;
  late MockRestoreTransfer restoreTransfer;

  TransactionEntity entity(
    String id, {
    TransactionType type = TransactionType.expense,
    String? transferId,
  }) {
    return TransactionEntity(
      id: id,
      workspaceId: 'w1',
      accountId: 'a1',
      categoryId: 'c1',
      type: type,
      status: TransactionStatus.posted,
      amountCents: 2500,
      currency: 'BRL',
      description: 'Item $id',
      occurredAt: DateTime(2026, 10, 2, 12),
      transferId: transferId,
    );
  }

  TrashedTransaction trashed(String id) {
    return TrashedTransaction(
      transaction: entity(id),
      deletedAt: DateTime(2026, 10, 5, 22),
    );
  }

  TrashedTransfer transfer(String id) {
    return TrashedTransfer(
      transferId: id,
      legs: [
        entity('$id-out', type: TransactionType.transferOut, transferId: id),
        entity('$id-in', type: TransactionType.transferIn, transferId: id),
      ],
      deletedAt: DateTime(2026, 10, 6, 9),
    );
  }

  final first = trashed('t1');
  final second = trashed('t2');
  final x1 = transfer('x1');
  final x2 = transfer('x2');

  setUp(() {
    getTrash = MockGetTrash();
    getTransfers = MockGetTransfers();
    restore = MockRestore();
    restoreTransfer = MockRestoreTransfer();
    when(() => getTrash('w1')).thenAnswer(
      (_) async => Right<Failure, List<TrashedTransaction>>([first, second]),
    );
    when(() => getTransfers('w1')).thenAnswer(
      (_) async => Right<Failure, List<TrashedTransfer>>([x1, x2]),
    );
  });

  TrashCubit buildCubit() => TrashCubit(
        getTrash: getTrash,
        getTransfers: getTransfers,
        restoreTransaction: restore,
        restoreTransfer: restoreTransfer,
      );

  TrashState loaded({
    List<TrashedTransaction>? items,
    List<TrashedTransfer>? transfers,
    Failure? actionFailure,
    TransactionEntity? restored,
    TrashedTransfer? restoredTransfer,
  }) {
    return TrashState(
      status: TrashStatus.loaded,
      items: items ?? [first, second],
      transfers: transfers ?? [x1, x2],
      actionFailure: actionFailure,
      restored: restored,
      restoredTransfer: restoredTransfer,
    );
  }

  blocTest<TrashCubit, TrashState>(
    'load emits loading then the transactions and the transfers',
    build: buildCubit,
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const TrashState(status: TrashStatus.loading),
      loaded(),
    ],
  );

  blocTest<TrashCubit, TrashState>(
    'load fails as a whole when the transactions fail',
    build: () {
      when(() => getTrash('w1')).thenAnswer(
        (_) async => const Left<Failure, List<TrashedTransaction>>(
          NetworkFailure('network_error'),
        ),
      );
      return buildCubit();
    },
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const TrashState(status: TrashStatus.loading),
      const TrashState(
        status: TrashStatus.failure,
        failure: NetworkFailure('network_error'),
      ),
    ],
  );

  blocTest<TrashCubit, TrashState>(
    'load fails as a whole when the transfers fail',
    build: () {
      when(() => getTransfers('w1')).thenAnswer(
        (_) async => const Left<Failure, List<TrashedTransfer>>(
          ServerFailure('unknown_error'),
        ),
      );
      return buildCubit();
    },
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const TrashState(status: TrashStatus.loading),
      const TrashState(
        status: TrashStatus.failure,
        failure: ServerFailure('unknown_error'),
      ),
    ],
  );

  blocTest<TrashCubit, TrashState>(
    'restoring a transaction removes it and leaves the transfers alone',
    build: () {
      when(() => restore('t1'))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      return buildCubit();
    },
    seed: loaded,
    act: (cubit) => cubit.restore(first),
    expect: () => [
      loaded(items: [second], restored: first.transaction),
    ],
    verify: (_) => verify(() => restore('t1')).called(1),
  );

  blocTest<TrashCubit, TrashState>(
    'a refused restore of a transaction keeps the list and reports why',
    build: () {
      when(() => restore('t1')).thenAnswer(
        (_) async => const Left<Failure, void>(
          RuleFailure('invoice already paid: its transactions are locked'),
        ),
      );
      return buildCubit();
    },
    seed: loaded,
    act: (cubit) => cubit.restore(first),
    expect: () => [
      loaded(
        actionFailure: const RuleFailure(
          'invoice already paid: its transactions are locked',
        ),
      ),
    ],
  );

  blocTest<TrashCubit, TrashState>(
    'restoring a transfer removes it and leaves the transactions alone',
    build: () {
      when(() => restoreTransfer('x1'))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      return buildCubit();
    },
    seed: loaded,
    act: (cubit) => cubit.restoreTransfer(x1),
    expect: () => [
      loaded(transfers: [x2], restoredTransfer: x1),
    ],
    verify: (_) => verify(() => restoreTransfer('x1')).called(1),
  );

  blocTest<TrashCubit, TrashState>(
    'a refused card payment keeps the list and reports why',
    build: () {
      when(() => restoreTransfer('x1')).thenAnswer(
        (_) async => const Left<Failure, void>(
          RuleFailure('a card payment cannot be restored: pay the invoice again'),
        ),
      );
      return buildCubit();
    },
    seed: loaded,
    act: (cubit) => cubit.restoreTransfer(x1),
    expect: () => [
      loaded(
        actionFailure: const RuleFailure(
          'a card payment cannot be restored: pay the invoice again',
        ),
      ),
    ],
  );

  blocTest<TrashCubit, TrashState>(
    'reload does nothing before the first load',
    build: buildCubit,
    act: (cubit) => cubit.reload(),
    expect: () => <TrashState>[],
    verify: (_) {
      verifyNever(() => getTrash(any()));
      verifyNever(() => getTransfers(any()));
    },
  );
}