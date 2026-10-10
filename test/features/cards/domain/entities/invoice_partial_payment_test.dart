import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  InvoiceEntity build({
    int total = 10000,
    int? paid,
    InvoiceStatus status = InvoiceStatus.closed,
  }) {
    return InvoiceEntity(
      id: 'i1',
      accountId: 'card1',
      referenceMonth: DateTime(2026, 3),
      periodStart: DateTime(2026, 2, 11),
      periodEnd: DateTime(2026, 3, 10),
      dueDate: DateTime(2026, 3, 17),
      status: status,
      totalCents: total,
      paidCents: paid ?? 0,
    );
  }

  group('remainingCents', () {
    test('is the whole total when nothing was paid', () {
      expect(build().remainingCents, 10000);
    });

    test('is the total minus what was paid', () {
      expect(build(paid: 3500).remainingCents, 6500);
    });

    test('is zero when everything was paid', () {
      expect(build(paid: 10000).remainingCents, 0);
    });

    test('is never below zero (a refund after the payment)', () {
      expect(build(total: 8000, paid: 10000).remainingCents, 0);
    });

    test('follows the total when a purchase joins the invoice', () {
      expect(build(total: 10700, paid: 3500).remainingCents, 7200);
    });
  });

  group('isPartiallyPaid', () {
    test('is true when part was paid and some is still owed', () {
      expect(build(paid: 3500).isPartiallyPaid, isTrue);
    });

    test('is false when nothing was paid', () {
      expect(build().isPartiallyPaid, isFalse);
    });

    test('is false when nothing is owed any more', () {
      expect(build(paid: 10000).isPartiallyPaid, isFalse);
    });

    test('is false for an invoice marked paid', () {
      expect(build(paid: 10000, status: InvoiceStatus.paid).isPartiallyPaid, isFalse);
    });

    test('is true for an open invoice with a payment on it', () {
      expect(build(paid: 100, status: InvoiceStatus.open).isPartiallyPaid, isTrue);
    });
  });

  group('needsPayment', () {
    test('is true when something is owed', () {
      expect(build().needsPayment, isTrue);
    });

    test('is true when part was paid and part is owed', () {
      expect(build(paid: 3500).needsPayment, isTrue);
    });

    test('is false when nothing is owed, even if the invoice is not marked paid', () {
      expect(build(paid: 10000).needsPayment, isFalse);
    });

    test('is false when the invoice is marked paid', () {
      expect(build(paid: 10000, status: InvoiceStatus.paid).needsPayment, isFalse);
    });

    test('is false for an invoice with no charges', () {
      expect(build(total: 0).needsPayment, isFalse);
    });
  });

  group('paidCents', () {
    test('is zero when it is not given', () {
      expect(build().paidCents, 0);
    });

    test('takes part in equality', () {
      expect(build(paid: 100), build(paid: 100));
      expect(build(paid: 100), isNot(build(paid: 200)));
    });
  });
}
