import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';

enum TransactionFormStatus { idle, submitting, success, failure }

class TransactionFormState extends Equatable {
  final TransactionFormStatus status;
  final Failure? failure;
  final TransactionEntity? transaction;

  const TransactionFormState({
    this.status = TransactionFormStatus.idle,
    this.failure,
    this.transaction,
  });

  @override
  List<Object?> get props => [status, failure, transaction];
}