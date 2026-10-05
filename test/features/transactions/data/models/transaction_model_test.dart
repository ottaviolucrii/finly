import 'package:finly/features/transactions/data/models/transaction_model.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const row = {
    'id': 't1',
    'workspace_id': 'w1',
    'account_id': 'a1',
    'category_id': 'c1',
    'type': 'expense',
    'status': 'posted',
    'amount_cents': 2500,
    'currency': 'BRL',
    'description': 'Mercado',
    'occurred_at': '2026-10-02T15:30:00+00:00',
  };

  test('reads every field of a transactions row', () {
    final model = TransactionModel.fromMap(row);

    expect(model.id, 't1');
    expect(model.workspaceId, 'w1');
    expect(model.accountId, 'a1');
    expect(model.categoryId, 'c1');
    expect(model.type, TransactionType.expense);
    expect(model.status, TransactionStatus.posted);
    expect(model.amountCents, 2500);
    expect(model.currency, 'BRL');
    expect(model.description, 'Mercado');
    expect(model.occurredAt.toUtc(), DateTime.utc(2026, 10, 2, 15, 30));
  });

  test('accepts a missing category and numbers that arrive as doubles', () {
    final model = TransactionModel.fromMap({
      ...row,
      'category_id': null,
      'amount_cents': 1250.0,
    });

    expect(model.categoryId, isNull);
    expect(model.amountCents, 1250);
  });

  test('an unknown type fails loudly instead of guessing', () {
    expect(
      () => TransactionModel.fromMap({...row, 'type': 'refund'}),
      throwsArgumentError,
    );
  });
}