import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';

enum TransactionsStatus { initial, loading, loaded, failure }

class TransactionsState extends Equatable {
  final TransactionsStatus status;
  final List<TransactionEntity> transactions;

  /// Loaded together with the transactions: the list shows account names and
  /// category icons, and the form needs both.
  final List<AccountEntity> accounts;
  final List<CategoryEntity> categories;

  /// Why loading failed (shown full screen with a retry button).
  final Failure? failure;

  /// Why an action such as confirming or deleting failed (shown as a message).
  final Failure? actionFailure;

  /// The transaction just deleted, so the page can offer "Desfazer".
  final TransactionEntity? deletedTransaction;

  const TransactionsState({
    this.status = TransactionsStatus.initial,
    this.transactions = const [],
    this.accounts = const [],
    this.categories = const [],
    this.failure,
    this.actionFailure,
    this.deletedTransaction,
  });

  /// Same data with a few things changed; failures and the deleted marker
  /// are cleared unless given.
  TransactionsState withData({
    TransactionsStatus? status,
    List<TransactionEntity>? transactions,
    Failure? actionFailure,
    TransactionEntity? deletedTransaction,
  }) {
    return TransactionsState(
      status: status ?? this.status,
      transactions: transactions ?? this.transactions,
      accounts: accounts,
      categories: categories,
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
        failure,
        actionFailure,
        deletedTransaction,
      ];
}