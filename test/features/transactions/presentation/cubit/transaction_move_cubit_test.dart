import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/domain/usecases/move_transaction_use_case.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_move_cubit.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_move_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAccounts extends Mock implements GetAccountsUseCase {}

class MockMove extends Mock implements MoveTransactionUseCase {}

void main() {
  late MockGetAccounts getAccounts;
  late MockMove move;

  AccountEntity account(
    String id,
    String name, {
    AccountType type = AccountType.checking,
    String currency = 'BRL',
  }) {
    return AccountEntity(
      id: id,
      workspaceId: 'w1',
      name: name,
      type: type,
      currency: currency,
      openingBalanceCents: 0,
      postedBalanceCents: 0,
      projectedBalanceCents: 0,
    );
  }

  final transaction = TransactionEntity(
    id: 't1',
    workspaceId: 'w1',
    accountId: 'a1',
    categoryId: null,
    type: TransactionType.expense,
    status: TransactionStatus.posted,
    amountCents: 2500,
    currency: 'BRL',
    description: 'Mercado',
    occurredAt: DateTime(2026, 10, 5, 12),
  );

  final savings = account('a2', 'Poupança');
  final card = account('a3', 'Cartão', type: AccountType.creditCard);
  const params = MoveTransactionParams(transactionId: 't1', accountId: 'a2');

  setUpAll(() => registerFallbackValue(params));

  setUp(() {
    getAccounts = MockGetAccounts();
    move = MockMove();
  });

  TransactionMoveCubit build() =>
      TransactionMoveCubit(getAccounts: getAccounts, moveTransaction: move);

  blocTest<TransactionMoveCubit, TransactionMoveState>(
    'load keeps only the accounts the transaction can go to (an expense may go to a card)',
    build: () {
      when(() => getAccounts('w1')).thenAnswer(
        (_) async => Right<Failure, List<AccountEntity>>([
          account('a1', 'Nubank'),
          savings,
          card,
          account('a4', 'Dólar', currency: 'USD'),
        ]),
      );
      return build();
    },
    act: (cubit) => cubit.load(transaction),
    expect: () => [
      TransactionMoveState(status: TransactionMoveStatus.ready, targets: [card, savings]),
    ],
  );

  blocTest<TransactionMoveCubit, TransactionMoveState>(
    'load with unreadable accounts is ready with none',
    build: () {
      when(() => getAccounts('w1')).thenAnswer(
        (_) async => const Left<Failure, List<AccountEntity>>(NetworkFailure('network_error')),
      );
      return build();
    },
    act: (cubit) => cubit.load(transaction),
    expect: () => [const TransactionMoveState(status: TransactionMoveStatus.ready)],
  );

  blocTest<TransactionMoveCubit, TransactionMoveState>(
    'a move emits moving then moved',
    build: () {
      when(() => move(params)).thenAnswer((_) async => const Right<Failure, void>(null));
      return build();
    },
    seed: () => TransactionMoveState(status: TransactionMoveStatus.ready, targets: [savings]),
    act: (cubit) => cubit.move(transactionId: 't1', accountId: 'a2'),
    expect: () => [
      TransactionMoveState(status: TransactionMoveStatus.moving, targets: [savings]),
      TransactionMoveState(status: TransactionMoveStatus.moved, targets: [savings]),
    ],
  );

  blocTest<TransactionMoveCubit, TransactionMoveState>(
    'a refused move emits the failure and keeps the accounts',
    build: () {
      when(() => move(params)).thenAnswer(
        (_) async => const Left<Failure, void>(RuleFailure('the account is archived')),
      );
      return build();
    },
    seed: () => TransactionMoveState(status: TransactionMoveStatus.ready, targets: [savings]),
    act: (cubit) => cubit.move(transactionId: 't1', accountId: 'a2'),
    expect: () => [
      TransactionMoveState(status: TransactionMoveStatus.moving, targets: [savings]),
      TransactionMoveState(
        status: TransactionMoveStatus.failure,
        targets: [savings],
        failure: const RuleFailure('the account is archived'),
      ),
    ],
  );

  test('a second move while one is running is ignored', () async {
    final gate = Completer<Either<Failure, void>>();
    when(() => move(any())).thenAnswer((_) => gate.future);
    final cubit = build();

    final first = cubit.move(transactionId: 't1', accountId: 'a2');
    await cubit.move(transactionId: 't1', accountId: 'a3');
    gate.complete(const Right<Failure, void>(null));
    await first;

    verify(() => move(any())).called(1);
    expect(cubit.state.status, TransactionMoveStatus.moved);
    await cubit.close();
  });

  test('starts loading, with no accounts yet', () {
    final cubit = build();

    expect(cubit.state.status, TransactionMoveStatus.loading);
    expect(cubit.state.targets, isEmpty);
    cubit.close();
  });
}
