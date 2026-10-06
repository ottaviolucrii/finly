import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/domain/usecases/get_all_categories_use_case.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_filter.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/domain/usecases/confirm_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/delete_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/get_transactions_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/restore_transaction_use_case.dart';
import 'package:finly/features/transactions/presentation/cubit/transactions_cubit.dart';
import 'package:finly/features/transactions/presentation/cubit/transactions_state.dart';
import 'package:finly/features/transfers/domain/usecases/delete_transfer_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetTransactions extends Mock implements GetTransactionsUseCase {}

class MockGetAccounts extends Mock implements GetAccountsUseCase {}

class MockGetCategories extends Mock implements GetAllCategoriesUseCase {}

class MockConfirm extends Mock implements ConfirmTransactionUseCase {}

class MockDelete extends Mock implements DeleteTransactionUseCase {}

class MockRestore extends Mock implements RestoreTransactionUseCase {}

class MockDeleteTransfer extends Mock implements DeleteTransferUseCase {}

void main() {
  late MockGetTransactions getTransactions;
  late MockGetAccounts getAccounts;
  late MockGetCategories getCategories;
  late MockConfirm confirm;
  late MockDelete delete;
  late MockRestore restore;
  late MockDeleteTransfer deleteTransfer;

  final occurredAt = DateTime(2026, 10, 2, 12);

  TransactionEntity transaction(
    String id, {
    TransactionStatus status = TransactionStatus.posted,
    String? transferId,
  }) {
    return TransactionEntity(
      id: id,
      workspaceId: 'w1',
      accountId: 'a1',
      categoryId: 'c1',
      type: TransactionType.expense,
      status: status,
      amountCents: 2500,
      currency: 'BRL',
      description: 'Mercado',
      occurredAt: occurredAt,
      transferId: transferId,
    );
  }

  List<TransactionEntity> rows(int from, int count) =>
      [for (var i = from; i < from + count; i++) transaction('t$i')];

  final first = transaction('t1');
  final second = transaction('t2');
  final pending = transaction('t1', status: TransactionStatus.pending);
  final legOut = transaction('l1', transferId: 'tr1');
  final legIn = transaction('l2', transferId: 'tr1');

  const account = AccountEntity(
    id: 'a1',
    workspaceId: 'w1',
    name: 'Nubank',
    type: AccountType.checking,
    currency: 'BRL',
    openingBalanceCents: 100000,
    postedBalanceCents: 100000,
    projectedBalanceCents: 100000,
  );
  const category = CategoryEntity(
    id: 'c1',
    workspaceId: 'w1',
    name: 'Alimentação',
    kind: CategoryKind.expense,
    icon: 'restaurant',
    colorHex: '#F29D38',
    isDefault: true,
  );

  const none = TransactionFilter();
  const onlyExpenses = TransactionFilter(type: TransactionType.expense);

  GetTransactionsParams page({
    int offset = 0,
    TransactionFilter filter = none,
  }) {
    return GetTransactionsParams(
      workspaceId: 'w1',
      limit: TransactionsCubit.pageSize,
      offset: offset,
      filter: filter,
    );
  }

  setUpAll(() => registerFallbackValue(page()));

  setUp(() {
    getTransactions = MockGetTransactions();
    getAccounts = MockGetAccounts();
    getCategories = MockGetCategories();
    confirm = MockConfirm();
    delete = MockDelete();
    restore = MockRestore();
    deleteTransfer = MockDeleteTransfer();

    when(() => getAccounts('w1')).thenAnswer(
      (_) async => const Right<Failure, List<AccountEntity>>([account]),
    );
    when(() => getCategories('w1')).thenAnswer(
      (_) async => const Right<Failure, List<CategoryEntity>>([category]),
    );
  });

  TransactionsCubit buildCubit() => TransactionsCubit(
        getTransactions: getTransactions,
        getAccounts: getAccounts,
        getCategories: getCategories,
        confirmTransaction: confirm,
        deleteTransaction: delete,
        restoreTransaction: restore,
        deleteTransfer: deleteTransfer,
      );

  void stubPage(
    List<TransactionEntity> list, {
    int offset = 0,
    TransactionFilter filter = none,
  }) {
    when(() => getTransactions(page(offset: offset, filter: filter))).thenAnswer(
      (_) async => Right<Failure, List<TransactionEntity>>(list),
    );
  }

  TransactionsState loaded(
    List<TransactionEntity> list, {
    TransactionFilter filter = none,
    bool hasMore = false,
    bool loadingMore = false,
    TransactionEntity? deleted,
    Failure? actionFailure,
  }) {
    return TransactionsState(
      status: TransactionsStatus.loaded,
      transactions: list,
      accounts: const [account],
      categories: const [category],
      filter: filter,
      hasMore: hasMore,
      loadingMore: loadingMore,
      deletedTransaction: deleted,
      actionFailure: actionFailure,
    );
  }

  TransactionsState loading(
    List<TransactionEntity> list, {
    TransactionFilter filter = none,
    bool hasMore = false,
  }) {
    return TransactionsState(
      status: TransactionsStatus.loading,
      transactions: list,
      accounts: list.isEmpty ? const [] : const [account],
      categories: list.isEmpty ? const [] : const [category],
      filter: filter,
      hasMore: hasMore,
    );
  }

  group('loading', () {
    blocTest<TransactionsCubit, TransactionsState>(
      'load emits loading then the first page and what the screen needs',
      build: () {
        stubPage([first, second]);
        return buildCubit();
      },
      act: (cubit) => cubit.load('w1'),
      expect: () => [
        loading(const []),
        loaded([first, second]),
      ],
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'a full page means there may be more',
      build: () {
        stubPage(rows(1, 20));
        return buildCubit();
      },
      act: (cubit) => cubit.load('w1'),
      expect: () => [
        loading(const []),
        loaded(rows(1, 20), hasMore: true),
      ],
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'load fails as a whole when any part fails',
      build: () {
        stubPage([first]);
        when(() => getCategories('w1')).thenAnswer(
          (_) async => const Left<Failure, List<CategoryEntity>>(
            NetworkFailure('network_error'),
          ),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.load('w1'),
      expect: () => [
        loading(const []),
        const TransactionsState(
          status: TransactionsStatus.failure,
          failure: NetworkFailure('network_error'),
        ),
      ],
    );
  });

  group('filter', () {
    blocTest<TransactionsCubit, TransactionsState>(
      'setFilter shows the first page of the filter without fetching the lookups again',
      build: () {
        stubPage([first, second]);
        stubPage([first], filter: onlyExpenses);
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.load('w1');
        await cubit.setFilter(onlyExpenses);
      },
      skip: 2,
      expect: () => [
        loading([first, second], filter: onlyExpenses),
        loaded([first], filter: onlyExpenses),
      ],
      verify: (_) {
        verify(() => getAccounts('w1')).called(1);
        verify(() => getCategories('w1')).called(1);
      },
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'setFilter with the same filter does nothing',
      build: () {
        stubPage([first]);
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.load('w1');
        await cubit.setFilter(none);
      },
      skip: 2,
      expect: () => <TransactionsState>[],
    );

    test('a slow answer to an old filter never replaces a newer one', () async {
      final slow = Completer<Either<Failure, List<TransactionEntity>>>();
      const incomeOnly = TransactionFilter(type: TransactionType.income);
      stubPage([first]);
      when(() => getTransactions(page(filter: incomeOnly)))
          .thenAnswer((_) => slow.future);
      stubPage([second], filter: onlyExpenses);

      final cubit = buildCubit();
      await cubit.load('w1');

      final older = cubit.setFilter(incomeOnly);
      await cubit.setFilter(onlyExpenses);
      // The old answer arrives late.
      slow.complete(const Right<Failure, List<TransactionEntity>>([]));
      await older;

      expect(cubit.state.filter, onlyExpenses);
      expect(cubit.state.transactions, [second]);
      await cubit.close();
    });
  });

  group('pagination', () {
    blocTest<TransactionsCubit, TransactionsState>(
      'loadMore adds the next page after the rows already loaded',
      build: () {
        stubPage(rows(1, 20));
        stubPage(rows(21, 5), offset: 20);
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.load('w1');
        await cubit.loadMore();
      },
      skip: 2,
      expect: () => [
        loaded(rows(1, 20), hasMore: true, loadingMore: true),
        loaded(rows(1, 25)),
      ],
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'loadMore does nothing when there are no more pages',
      build: () {
        stubPage([first, second]);
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.load('w1');
        await cubit.loadMore();
      },
      skip: 2,
      expect: () => <TransactionsState>[],
      verify: (_) => verify(() => getTransactions(any())).called(1),
    );

        blocTest<TransactionsCubit, TransactionsState>(
      'loadMore never shows the same row twice',
      build: () {
        stubPage(rows(1, 20));
        // A row was added meanwhile, so the next page repeats t20.
        stubPage([transaction('t20'), transaction('t21')], offset: 20);
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.load('w1');
        await cubit.loadMore();
      },
      skip: 4,
      expect: () => <TransactionsState>[],
      verify: (cubit) {
        final ids = cubit.state.transactions.map((t) => t.id).toList();
        expect(ids.toSet().length, ids.length);
        expect(ids.length, 21);
      },
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'a failed loadMore keeps the rows and reports the reason',
      build: () {
        stubPage(rows(1, 20));
        when(() => getTransactions(page(offset: 20))).thenAnswer(
          (_) async => const Left<Failure, List<TransactionEntity>>(
            NetworkFailure('network_error'),
          ),
        );
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.load('w1');
        await cubit.loadMore();
      },
      skip: 3,
      expect: () => [
        loaded(
          rows(1, 20),
          hasMore: true,
          actionFailure: const NetworkFailure('network_error'),
        ),
      ],
    );
  });

  group('actions', () {
    blocTest<TransactionsCubit, TransactionsState>(
      'confirm marks the transaction as posted and reloads',
      build: () {
        stubPage([pending]);
        when(() => confirm('t1'))
            .thenAnswer((_) async => const Right<Failure, void>(null));
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.load('w1');
        stubPage([first]);
        await cubit.confirm('t1');
      },
      expect: () => [
        loading(const []),
        loaded([pending]),
        loading([pending]),
        loaded([first]),
      ],
      verify: (_) => verify(() => confirm('t1')).called(1),
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'delete removes the row at once and offers to undo',
      build: () {
        when(() => delete('t1'))
            .thenAnswer((_) async => const Right<Failure, void>(null));
        return buildCubit();
      },
      seed: () => loaded([first, second]),
      act: (cubit) => cubit.delete(first),
      expect: () => [loaded([second], deleted: first)],
      verify: (_) => verify(() => delete('t1')).called(1),
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'delete puts the row back when the server refuses',
      build: () {
        when(() => delete('t1')).thenAnswer(
          (_) async =>
              const Left<Failure, void>(PermissionFailure('forbidden')),
        );
        return buildCubit();
      },
      seed: () => loaded([first, second]),
      act: (cubit) => cubit.delete(first),
      expect: () => [
        loaded([second], deleted: first),
        loaded(
          [first, second],
          actionFailure: const PermissionFailure('forbidden'),
        ),
      ],
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'undoDelete restores the transaction and reloads',
      build: () {
        stubPage([first, second]);
        when(() => delete('t1'))
            .thenAnswer((_) async => const Right<Failure, void>(null));
        when(() => restore('t1'))
            .thenAnswer((_) async => const Right<Failure, void>(null));
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.load('w1');
        await cubit.delete(first);
        await cubit.undoDelete();
      },
      expect: () => [
        loading(const []),
        loaded([first, second]),
        loaded([second], deleted: first),
        loading([second]),
        loaded([first, second]),
      ],
      verify: (_) => verify(() => restore('t1')).called(1),
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'deleteTransfer removes both ends from the list and calls the server once',
      build: () {
        when(() => deleteTransfer('tr1'))
            .thenAnswer((_) async => const Right<Failure, void>(null));
        return buildCubit();
      },
      seed: () => loaded([legOut, legIn, first]),
      act: (cubit) => cubit.deleteTransfer(legOut),
      expect: () => [loaded([first])],
      verify: (_) => verify(() => deleteTransfer('tr1')).called(1),
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'deleteTransfer puts both ends back when the server refuses',
      build: () {
        when(() => deleteTransfer('tr1')).thenAnswer(
          (_) async =>
              const Left<Failure, void>(PermissionFailure('forbidden')),
        );
        return buildCubit();
      },
      seed: () => loaded([legOut, legIn, first]),
      act: (cubit) => cubit.deleteTransfer(legOut),
      expect: () => [
        loaded([first]),
        loaded(
          [legOut, legIn, first],
          actionFailure: const PermissionFailure('forbidden'),
        ),
      ],
    );

    blocTest<TransactionsCubit, TransactionsState>(
      'deleteTransfer ignores a transaction that is not part of a transfer',
      build: buildCubit,
      seed: () => loaded([first]),
      act: (cubit) => cubit.deleteTransfer(first),
      expect: () => <TransactionsState>[],
      verify: (_) => verifyNever(() => deleteTransfer(any())),
    );
  });
}