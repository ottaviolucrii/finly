import 'package:finly/features/recurring/data/models/recurring_model.dart';
import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const row = {
    'id': 'r1',
    'workspace_id': 'w1',
    'account_id': 'a1',
    'category_id': 'c1',
    'type': 'expense',
    'amount_cents': 120000,
    'currency': 'BRL',
    'description': 'Aluguel',
    'frequency': 'monthly',
    'interval_count': 1,
    'start_date': '2026-03-05',
    'end_date': '2026-12-05',
    'is_active': true,
  };

  test('reads every field of a recurring_transactions row', () {
    final model = RecurringModel.fromMap(row);

    expect(model.id, 'r1');
    expect(model.workspaceId, 'w1');
    expect(model.accountId, 'a1');
    expect(model.categoryId, 'c1');
    expect(model.type, TransactionType.expense);
    expect(model.amountCents, 120000);
    expect(model.currency, 'BRL');
    expect(model.description, 'Aluguel');
    expect(model.frequency, RecurrenceFrequency.monthly);
    expect(model.intervalCount, 1);
    expect(model.startDate, DateTime(2026, 3, 5));
    expect(model.endDate, DateTime(2026, 12, 5));
    expect(model.isActive, isTrue);
  });

  test('accepts a missing category and a missing end date', () {
    final model = RecurringModel.fromMap({
      ...row,
      'category_id': null,
      'end_date': null,
    });

    expect(model.categoryId, isNull);
    expect(model.endDate, isNull);
  });

  test('reads numbers that arrive as doubles', () {
    final model = RecurringModel.fromMap({
      ...row,
      'amount_cents': 120000.0,
      'interval_count': 2.0,
    });

    expect(model.amountCents, 120000);
    expect(model.intervalCount, 2);
  });

  test('an unknown frequency fails loudly instead of guessing', () {
    expect(
      () => RecurringModel.fromMap({...row, 'frequency': 'hourly'}),
      throwsArgumentError,
    );
  });
}