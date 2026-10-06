import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/domain/usecases/restore_transaction_use_case.dart';
import 'package:finly/features/trash/domain/entities/trashed_transaction.dart';
import 'package:finly/features/trash/domain/usecases/get_trash_use_case.dart';
import 'package:finly/features/trash/presentation/cubit/trash_cubit.dart';
import 'package:finly/features/trash/presentation/cubit/trash_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetTrash extends Mock implements GetTrashUseCase {}

class MockRestore extends Mock implements RestoreTransactionUseCase {}

void main() {
  late MockGetTrash getTrash;
  late MockRestore restore;

  TrashedTransaction trashed(String id) {
    return TrashedTransaction(
      transaction: TransactionEntity(
        id: id,
        workspaceId: 'w1',
        accountId: 'a1',
        categoryId: 'c1',
        type: TransactionType.expense,
        status: TransactionStatus.posted,
        amountCents: 2500,
        currency: 'BRL',
        description: 'Mercado $id',
        occurredAt: DateTime(2026, 10, 2, 12),
      ),
      deletedAt: DateTime(2026, 10, 5, 22),
    );
  }

  final first = trashed('t1');
  final second = trashed('t2');

  setUp(() {
    getTrash = MockGetTrash();
    restore = MockRestore();
    when(() => getTrash('w1')).thenAnswer(
      (_) async => Right<Failure, List<TrashedTransaction>>([first, second]),
    );
  });

  TrashCubit buildCubit() =>
      TrashCubit(getTrash: getTrash, restoreTransaction: restore);

  blocTest<TrashCubit, TrashState>(
    'load emits loading then the trash',
    build: buildCubit,
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const TrashState(status: TrashStatus.loading),
      TrashState(status: TrashStatus.loaded, items: [first, second]),
    ],
  );

  blocTest<TrashCubit, TrashState>(
    'load emits loading then failure',
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
    'restoring removes the item from the list and says what came back',
    build: () {
      when(() => restore('t1'))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      return buildCubit();
    },
    seed: () => TrashState(status: TrashStatus.loaded, items: [first, second]),
    act: (cubit) => cubit.restore(first),
    expect: () => [
      TrashState(
        status: TrashStatus.loaded,
        items: [second],
        restored: first.transaction,
      ),
    ],
    verify: (_) => verify(() => restore('t1')).called(1),
  );

  blocTest<TrashCubit, TrashState>(
    'a refused restore keeps the list and reports why',
    build: () {
      when(() => restore('t1')).thenAnswer(
        (_) async => const Left<Failure, void>(
          RuleFailure('invoice already paid: its transactions are locked'),
        ),
      );
      return buildCubit();
    },
    seed: () => TrashState(status: TrashStatus.loaded, items: [first, second]),
    act: (cubit) => cubit.restore(first),
    expect: () => [
      TrashState(
        status: TrashStatus.loaded,
        items: [first, second],
        actionFailure: const RuleFailure(
          'invoice already paid: its transactions are locked',
        ),
      ),
    ],
  );

  blocTest<TrashCubit, TrashState>(
    'reload does nothing before the first load',
    build: buildCubit,
    act: (cubit) => cubit.reload(),
    expect: () => <TrashState>[],
    verify: (_) => verifyNever(() => getTrash(any())),
  );
}