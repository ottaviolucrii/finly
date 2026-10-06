import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_filter.dart';

enum TransactionsStatus { initial, loading, loaded, failure }

class TransactionsState extends Equatable {
  final TransactionsStatus status;

  /// The pages loaded so far, newest first.
  final List<TransactionEntity> transactions;

  /// Loaded together with the first page: the list shows account names and
  /// category icons, and the forms and the filter sheet need both.
  final List<AccountEntity> accounts;
  final List<CategoryEntity> categories;

  /// What the list is narrowed down to.
  final TransactionFilter filter;

  /// There may be more pages after the ones loaded.
  final bool hasMore;

  /// The next page is being fetched.
  final bool loadingMore;

  /// Why loading failed (shown full screen with a retry button).
  final Failure? failure;

  /// Why an action such as confirming, deleting or loading more failed
  /// (shown as a message).
  final Failure? actionFailure;

  /// The transaction just deleted, so the page can offer "Desfazer".
  final TransactionEntity? deletedTransaction;

  const TransactionsState({
    this.status = TransactionsStatus.initial,
    this.transactions = const [],
    this.accounts = const [],
    this.categories = const [],
    this.filter = const TransactionFilter(),
    this.hasMore = false,
    this.loadingMore = false,
    this.failure,
    this.actionFailure,
    this.deletedTransaction,
  });

  /// Same data with a few things changed; failures and the deleted marker
  /// are cleared unless given.
  TransactionsState withData({
    TransactionsStatus? status,
    List<TransactionEntity>? transactions,
    bool? hasMore,
    bool? loadingMore,
    Failure? actionFailure,
    TransactionEntity? deletedTransaction,
  }) {
    return TransactionsState(
      status: status ?? this.status,
      transactions: transactions ?? this.transactions,
      accounts: accounts,
      categories: categories,
      filter: filter,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      actionFailure: actionFailure,
      deletedTransaction: deletedTransaction,
    );
  }

  @override
  List<Object?> get props => [
        status,
        transactions,
        accounts,
        categories,
        filter,
        hasMore,
        loadingMore,
        failure,
        actionFailure,
        deletedTransaction,
      ];
}