import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/domain/usecases/get_categories_use_case.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
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

class MockGetCategories extends Mock implements GetCategoriesUseCase {}

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
    String id,
    TransactionStatus status, {
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

  final first = transaction('t1', TransactionStatus.posted);
  final second = transaction('t2', TransactionStatus.posted);
  final pending = transaction('t1', TransactionStatus.pending);
  final legOut = transaction('l1', TransactionStatus.posted, transferId: 'tr1');
  final legIn = transaction('l2', TransactionStatus.posted, transferId: 'tr1');

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

  void stubTransactions(List<TransactionEntity> list) {
    when(() => getTransactions('w1')).thenAnswer(
      (_) async => Right<Failure, List<TransactionEntity>>(list),
    );
  }

  TransactionsState loaded(
    List<TransactionEntity> list, {
    TransactionEntity? deleted,
    Failure? actionFailure,
  }) {
    return TransactionsState(
      status: TransactionsStatus.loaded,
      transactions: list,
      accounts: const [account],
      categories: const [category],
      deletedTransaction: deleted,
      actionFailure: actionFailure,
    );
  }

  TransactionsState loading(List<TransactionEntity> list) {
    return TransactionsState(
      status: TransactionsStatus.loading,
      transactions: list,
      accounts: list.isEmpty ? const [] : const [account],
      categories: list.isEmpty ? const [] : const [category],
    );
  }

  blocTest<TransactionsCubit, TransactionsState>(
    'load emits loading then everything the screen needs',
    build: () {
      stubTransactions([first, second]);
      return buildCubit();
    },
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      loading(const []),
      loaded([first, second]),
    ],
  );

  blocTest<TransactionsCubit, TransactionsState>(
    'load fails as a whole when any part fails',
    build: () {
      stubTransactions([first]);
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

  blocTest<TransactionsCubit, TransactionsState>(
    'confirm marks the transaction as posted and reloads',
    build: () {
      stubTransactions([pending]);
      when(() => confirm('t1'))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      return buildCubit();
    },
    act: (cubit) async {
      await cubit.load('w1');
      stubTransactions([first]);
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
      stubTransactions([first, second]);
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
}