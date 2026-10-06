import 'package:finly/features/dashboard/data/models/cash_flow_entry_model.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const row = {
    'type': 'expense',
    'status': 'posted',
    'amount_cents': 12000,
    'currency': 'BRL',
  };

  test('reads the four columns of a transactions row', () {
    final model = CashFlowEntryModel.fromMap(row);

    expect(model.type, TransactionType.expense);
    expect(model.status, TransactionStatus.posted);
    expect(model.amountCents, 12000);
    expect(model.currency, 'BRL');
  });

  test('reads numbers that arrive as doubles', () {
    final model = CashFlowEntryModel.fromMap({...row, 'amount_cents': 12000.0});

    expect(model.amountCents, 12000);
  });

  test('an unknown status fails loudly instead of guessing', () {
    expect(
      () => CashFlowEntryModel.fromMap({...row, 'status': 'done'}),
      throwsArgumentError,
    );
  });
}