import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TransactionEntity build({
    TransactionType type = TransactionType.expense,
    TransactionStatus status = TransactionStatus.posted,
    int amountCents = 1250,
  }) {
    return TransactionEntity(
      id: 't1',
      workspaceId: 'w1',
      accountId: 'a1',
      categoryId: null,
      type: type,
      status: status,
      amountCents: amountCents,
      currency: 'BRL',
      description: 'Mercado',
      occurredAt: DateTime(2026, 10, 2, 12),
    );
  }

  test('an expense has a negative signed amount', () {
    expect(build(type: TransactionType.expense).signedCents, -1250);
  });

  test('income and incoming transfers have a positive signed amount', () {
    expect(build(type: TransactionType.income).signedCents, 1250);
    expect(build(type: TransactionType.transferIn).signedCents, 1250);
  });

  test('exposes the amount as Money', () {
    expect(build().amount.format(), r'R$ 12,50');
  });

  test('knows whether it is pending', () {
    expect(build(status: TransactionStatus.pending).isPending, isTrue);
    expect(build(status: TransactionStatus.posted).isPending, isFalse);
  });
}