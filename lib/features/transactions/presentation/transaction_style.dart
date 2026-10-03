import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter/material.dart';

/// "+ R$ 25,00" for money in, "- R$ 25,00" for money out. The sign is always
/// shown so colour is never the only signal.
String transactionAmountText(TransactionEntity transaction) {
  final sign = transaction.type.isCredit ? '+' : '-';
  return '$sign ${transaction.amount.format()}';
}

String transactionStatusLabel(TransactionStatus status) => switch (status) {
      TransactionStatus.pending => 'Pendente',
      TransactionStatus.posted => 'Confirmada',
      TransactionStatus.failed => 'Falhou',
    };

IconData transactionTypeIcon(TransactionType type) => switch (type) {
      TransactionType.income => Icons.arrow_downward,
      TransactionType.expense => Icons.arrow_upward,
      TransactionType.transferIn => Icons.swap_horiz,
      TransactionType.transferOut => Icons.swap_horiz,
    };