import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';

enum InvoiceDetailStatus { initial, loading, loaded, failure }

class InvoiceDetailState extends Equatable {
  final InvoiceDetailStatus status;

  /// The purchases (and refunds) inside the invoice.
  final List<TransactionEntity> transactions;
  final Failure? failure;

  const InvoiceDetailState({
    this.status = InvoiceDetailStatus.initial,
    this.transactions = const [],
    this.failure,
  });

  @override
  List<Object?> get props => [status, transactions, failure];
}