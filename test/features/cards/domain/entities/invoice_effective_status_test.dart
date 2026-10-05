import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  InvoiceEntity invoice(InvoiceStatus status) {
    return InvoiceEntity(
      id: 'i1',
      accountId: 'a1',
      referenceMonth: DateTime(2026, 3),
      periodStart: DateTime(2026, 2, 11),
      periodEnd: DateTime(2026, 3, 10),
      dueDate: DateTime(2026, 3, 17),
      status: status,
      totalCents: 10000,
    );
  }

  test('an open invoice stays open until its last day ends', () {
    expect(
      invoice(InvoiceStatus.open).statusOn(DateTime(2026, 3, 9, 23, 59)),
      InvoiceStatus.open,
    );
    expect(
      invoice(InvoiceStatus.open).statusOn(DateTime(2026, 3, 10, 23, 59)),
      InvoiceStatus.open,
    );
  });

  test('an open invoice whose cycle ended is shown as closed', () {
    expect(
      invoice(InvoiceStatus.open).statusOn(DateTime(2026, 3, 11, 0, 1)),
      InvoiceStatus.closed,
    );
    expect(
      invoice(InvoiceStatus.open).statusOn(DateTime(2026, 4, 1)),
      InvoiceStatus.closed,
    );
  });

  test('closed and paid invoices keep their status', () {
    expect(
      invoice(InvoiceStatus.closed).statusOn(DateTime(2026, 3, 5)),
      InvoiceStatus.closed,
    );
    expect(
      invoice(InvoiceStatus.paid).statusOn(DateTime(2026, 6, 1)),
      InvoiceStatus.paid,
    );
  });
}