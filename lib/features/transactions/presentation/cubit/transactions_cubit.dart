import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/categories/domain/usecases/get_all_categories_use_case.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_filter.dart';
import 'package:finly/features/transactions/domain/usecases/confirm_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/delete_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/get_transactions_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/restore_transaction_use_case.dart';
import 'package:finly/features/transactions/presentation/cubit/transactions_state.dart';
import 'package:finly/features/transfers/domain/usecases/delete_transfer_use_case.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransactionsCubit extends Cubit<TransactionsState> {
  /// Rows loaded at a time.
  static const pageSize = 20;

  final GetTransactionsUseCase _getTransactions;
  final GetAccountsUseCase _getAccounts;
  final GetAllCategoriesUseCase _getCategories;
  final ConfirmTransactionUseCase _confirmTransaction;
  final DeleteTransactionUseCase _deleteTransaction;
  final RestoreTransactionUseCase _restoreTransaction;
  final DeleteTransferUseCase _deleteTransfer;
  String? _workspaceId;

  /// Numbers each request, so that a slow answer to an old search never
  /// replaces the answer to a newer one.
  int _request = 0;

  TransactionsCubit({
    required GetTransactionsUseCase getTransactions,
    required GetAccountsUseCase getAccounts,
    required GetAllCategoriesUseCase getCategories,
    required ConfirmTransactionUseCase confirmTransaction,
    required DeleteTransactionUseCase deleteTransaction,
    required RestoreTransactionUseCase restoreTransaction,
    required DeleteTransferUseCase deleteTransfer,
  })  : _getTransactions = getTransactions,
        _getAccounts = getAccounts,
        _getCategories = getCategories,
        _confirmTransaction = confirmTransaction,
        _deleteTransaction = deleteTransaction,
        _restoreTransaction = restoreTransaction,
        _deleteTransfer = deleteTransfer,
        super(const TransactionsState());

  Future<void> load(String workspaceId) async {
    _workspaceId = workspaceId;
    await _refresh(lookups: true);
  }

  /// Back to the first page with the current filter. Used after anything
  /// that may have changed the list.
  Future<void> reload() => _refresh(lookups: true);

  /// Applies a new filter and shows its first page. The accounts and the
  /// categories are not fetched again.
  Future<void> setFilter(TransactionFilter filter) async {
    if (filter == state.filter) return;
    await _refresh(lookups: false, filter: filter);
  }

  Future<void> _refresh({required bool lookups, TransactionFilter? filter}) async {
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;

    final activeFilter = filter ?? state.filter;
    final request = ++_request;
    var accountList = state.accounts;
    var categoryList = state.categories;

    // Keep the old rows on screen while loading, to avoid flicker.
    emit(TransactionsState(
      status: TransactionsStatus.loading,
      transactions: state.transactions,
      accounts: accountList,
      categories: categoryList,
      filter: activeFilter,
      hasMore: state.hasMore,
    ));

    final transactions = await _getTransactions(
      GetTransactionsParams(
        workspaceId: workspaceId,
        limit: pageSize,
        filter: activeFilter,
      ),
    );

    Failure? failure;
    var page = const <TransactionEntity>[];
    transactions.fold((f) {
      failure ??= f;
    }, (value) {
      page = value;
    });

    if (lookups) {
      final accounts = await _getAccounts(workspaceId);
      final categories = await _getCategories(workspaceId);
      accounts.fold((f) {
        failure ??= f;
      }, (value) {
        accountList = value;
      });
      categories.fold((f) {
        failure ??= f;
      }, (value) {
        categoryList = value;
      });
    }

    // A newer request took over while this one was waiting.
    if (request != _request) return;

    final problem = failure;
    if (problem != null) {
      emit(TransactionsState(
        status: TransactionsStatus.failure,
        filter: activeFilter,
        failure: problem,
      ));
      return;
    }

    emit(TransactionsState(
      status: TransactionsStatus.loaded,
      transactions: page,
      accounts: accountList,
      categories: categoryList,
      filter: activeFilter,
      hasMore: page.length == pageSize,
    ));
  }

  /// Loads the next page and adds it to the list.
  Future<void> loadMore() async {
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;
    if (state.status != TransactionsStatus.loaded ||
        !state.hasMore ||
        state.loadingMore) {
      return;
    }

    final request = ++_request;
    final before = state;
    emit(before.withData(loadingMore: true));

    final result = await _getTransactions(
      GetTransactionsParams(
        workspaceId: workspaceId,
        limit: pageSize,
        offset: before.transactions.length,
        filter: before.filter,
      ),
    );
    if (request != _request) return;

    result.fold(
      (failure) => emit(state.withData(loadingMore: false, actionFailure: failure)),
      (page) {
        // Rows added in the meantime may shift a page: never show one twice.
        final known = {for (final t in state.transactions) t.id};
        final fresh = page.where((t) => !known.contains(t.id)).toList();
        emit(state.withData(
          transactions: [...state.transactions, ...fresh],
          hasMore: page.length == pageSize,
          loadingMore: false,
        ));
      },
    );
  }

  /// Marks a pending transaction as posted, then reloads.
  Future<void> confirm(String transactionId) async {
    final result = await _confirmTransaction(transactionId);
    await result.fold<Future<void>>(
      (failure) async => emit(state.withData(actionFailure: failure)),
      (_) => reload(),
    );
  }

  /// Removes the transaction from the list at once (a swiped row must leave
  /// the tree in the same frame), then tells the server. If the server
  /// refuses, the list is put back.
  Future<void> delete(TransactionEntity transaction) async {
    final previous = state;
    emit(previous.withData(
      transactions:
          previous.transactions.where((t) => t.id != transaction.id).toList(),
      deletedTransaction: transaction,
    ));

    final result = await _deleteTransaction(transaction.id);
    result.fold(
      (failure) => emit(previous.withData(actionFailure: failure)),
      (_) {},
    );
  }

  /// The "Desfazer" of a delete.
  Future<void> undoDelete() async {
    final deleted = state.deletedTransaction;
    if (deleted == null) return;

    final result = await _restoreTransaction(deleted.id);
    await result.fold<Future<void>>(
      (failure) async => emit(state.withData(actionFailure: failure)),
      (_) => reload(),
    );
  }

  /// Deletes a whole transfer (both entries) from one of its ends. There is
  /// no undo: the database restores single transactions, not transfers.
  Future<void> deleteTransfer(TransactionEntity leg) async {
    final transferId = leg.transferId;
    if (transferId == null) return;

    final previous = state;
    emit(previous.withData(
      transactions: previous.transactions
          .where((t) => t.transferId != transferId)
          .toList(),
    ));

    final result = await _deleteTransfer(transferId);
    result.fold(
      (failure) => emit(previous.withData(actionFailure: failure)),
      (_) {},
    );
  }
}