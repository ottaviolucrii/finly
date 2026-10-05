import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/presentation/transaction_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TransactionEntity build(TransactionType type) {
    return TransactionEntity(
      id: 't1',
      workspaceId: 'w1',
      accountId: 'a1',
      categoryId: null,
      type: type,
      status: TransactionStatus.posted,
      amountCents: 2500,
      currency: 'BRL',
      description: 'Mercado',
      occurredAt: DateTime(2026, 10, 2, 12),
    );
  }

  test('an expense shows a minus sign', () {
    expect(
      transactionAmountText(build(TransactionType.expense)),
      r'- R$ 25,00',
    );
  });

  test('income and incoming transfers show a plus sign', () {
    expect(
      transactionAmountText(build(TransactionType.income)),
      r'+ R$ 25,00',
    );
    expect(
      transactionAmountText(build(TransactionType.transferIn)),
      r'+ R$ 25,00',
    );
  });

  test('status labels are in Portuguese', () {
    expect(transactionStatusLabel(TransactionStatus.pending), 'Pendente');
    expect(transactionStatusLabel(TransactionStatus.posted), 'Confirmada');
    expect(transactionStatusLabel(TransactionStatus.failed), 'Falhou');
  });

  test('each type has an icon', () {
    expect(transactionTypeIcon(TransactionType.income), Icons.arrow_downward);
    expect(transactionTypeIcon(TransactionType.expense), Icons.arrow_upward);
    expect(transactionTypeIcon(TransactionType.transferIn), Icons.swap_horiz);
  });
}