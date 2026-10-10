import 'package:finly/features/cards/data/models/invoice_model.dart';
import 'package:finly/features/cards/domain/entities/invoice_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const row = <String, dynamic>{
    'id': 'i1',
    'account_id': 'card1',
    'reference_month': '2026-03-01',
    'period_start': '2026-02-11',
    'period_end': '2026-03-10',
    'due_date': '2026-03-17',
    'status': 'closed',
  };

  test('reads what was paid, next to the total', () {
    final model = InvoiceModel.fromMap(row, totalCents: 43335, paidCents: 10000);

    expect(model.totalCents, 43335);
    expect(model.paidCents, 10000);
    expect(model.remainingCents, 33335);
    expect(model.status, InvoiceStatus.closed);
  });

  test('nothing paid is the default', () {
    final model = InvoiceModel.fromMap(row, totalCents: 500);

    expect(model.paidCents, 0);
    expect(model.isPartiallyPaid, isFalse);
  });

  test('an invoice with no balance row has no total and nothing paid', () {
    final model = InvoiceModel.fromMap(row);

    expect(model.totalCents, 0);
    expect(model.paidCents, 0);
    expect(model.needsPayment, isFalse);
  });

  test('a partly paid invoice is reported as such', () {
    final model = InvoiceModel.fromMap(row, totalCents: 1000, paidCents: 400);

    expect(model.isPartiallyPaid, isTrue);
    expect(model.needsPayment, isTrue);
  });
}
