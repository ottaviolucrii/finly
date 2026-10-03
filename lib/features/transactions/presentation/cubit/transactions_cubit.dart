import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/usecases/get_categories_use_case.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/usecases/confirm_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/delete_transaction_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/get_transactions_use_case.dart';
import 'package:finly/features/transactions/domain/usecases/restore_transaction_use_case.dart';
import 'package:finly/features/transactions/presentation/cubit/transactions_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransactionsCubit extends Cubit<TransactionsState> {
  final GetTransactionsUseCase _getTransactions;
  final GetAccountsUseCase _getAccounts;
  final GetCategoriesUseCase _getCategories;
  final ConfirmTransactionUseCase _confirmTransaction;
  final DeleteTransactionUseCase _deleteTransaction;
  final RestoreTransactionUseCase _restoreTransaction;
  String? _workspaceId;

  TransactionsCubit({
    required GetTransactionsUseCase getTransactions,
    required GetAccountsUseCase getAccounts,
    required GetCategoriesUseCase getCategories,
    required ConfirmTransactionUseCase confirmTransaction,
    required DeleteTransactionUseCase deleteTransaction,
    required RestoreTransactionUseCase restoreTransaction,
  })  : _getTransactions = getTransactions,
        _getAccounts = getAccounts,
        _getCategories = getCategories,
        _confirmTransaction = confirmTransaction,
        _deleteTransaction = deleteTransaction,
        _restoreTransaction = restoreTransaction,
        super(const TransactionsState());

  Future<void> load(String workspaceId) async {
    _workspaceId = workspaceId;
    // Keep the old data on screen while reloading, to avoid flicker.
    emit(TransactionsState(
      status: TransactionsStatus.loading,
      transactions: state.transactions,
      accounts: state.accounts,
      categories: state.categories,
    ));

    final transactions = await _getTransactions(workspaceId);
    final accounts = await _getAccounts(workspaceId);
    final categories = await _getCategories(workspaceId);

    Failure? failure;
    var transactionList = const <TransactionEntity>[];
    var accountList = const <AccountEntity>[];
    var categoryList = const <CategoryEntity>[];

    transactions.fold((f) {
      failure ??= f;
    }, (value) {
      transactionList = value;
    });
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

    final loadFailure = failure;
    if (loadFailure != null) {
      emit(TransactionsState(
        status: TransactionsStatus.failure,
        failure: loadFailure,
      ));
      return;
    }

    emit(TransactionsState(
      status: TransactionsStatus.loaded,
      transactions: transactionList,
      accounts: accountList,
      categories: categoryList,
    ));
  }

  Future<void> reload() async {
    final id = _workspaceId;
    if (id != null) await load(id);
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
}