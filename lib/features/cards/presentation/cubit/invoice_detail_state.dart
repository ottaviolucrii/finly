import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';

enum InvoiceDetailStatus { initial, loading, loaded, failure }

class InvoiceDetailState extends Equatable {
  final InvoiceDetailStatus status;

  /// The invoice, refreshed on every load (paying changes its status).
  final InvoiceEntity? invoice;

  /// The purchases (and refunds) inside the invoice.
  final List<TransactionEntity> transactions;

  /// Accounts that can pay the invoice: same currency as the card, and not a
  /// card themselves.
  final List<AccountEntity> accounts;

  /// A payment is in progress.
  final bool paying;

  /// Why loading failed (shown full screen with a retry button).
  final Failure? failure;

  /// Why a payment failed (shown as a message).
  final Failure? actionFailure;

  const InvoiceDetailState({
    this.status = InvoiceDetailStatus.initial,
    this.invoice,
    this.transactions = const [],
    this.accounts = const [],
    this.paying = false,
    this.failure,
    this.actionFailure,
  });

  /// Same data with the payment flags changed; [actionFailure] is cleared
  /// unless given.
  InvoiceDetailState withChanges({bool? paying, Failure? actionFailure}) {
    return InvoiceDetailState(
      status: status,
      invoice: invoice,
      transactions: transactions,
      accounts: accounts,
      paying: paying ?? this.paying,
      failure: failure,
      actionFailure: actionFailure,
    );
  }

  @override
  List<Object?> get props => [
        status,
        invoice,
        transactions,
        accounts,
        paying,
        failure,
        actionFailure,
      ];
}