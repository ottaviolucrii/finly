import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CreditCardEntity card({int limitCents = 500000, int usedCents = 125000}) {
    return CreditCardEntity(
      accountId: 'a1',
      workspaceId: 'w1',
      name: 'Nubank Roxinho',
      currency: 'BRL',
      limitCents: limitCents,
      closingDay: 10,
      dueDay: 17,
      usedCents: usedCents,
    );
  }

  group('InvoiceStatus', () {
    test('database labels match the enum and survive a round trip', () {
      expect(InvoiceStatus.open.dbValue, 'open');
      expect(InvoiceStatus.closed.dbValue, 'closed');
      expect(InvoiceStatus.paid.dbValue, 'paid');
      for (final status in InvoiceStatus.values) {
        expect(InvoiceStatus.fromDb(status.dbValue), status);
      }
    });

    test('an unknown label fails loudly', () {
      expect(() => InvoiceStatus.fromDb('overdue'), throwsArgumentError);
    });
  });

  group('CreditCardEntity', () {
    test('available limit is the limit minus the debt', () {
      expect(card().availableCents, 375000);
      expect(card().available.format(), r'R$ 3.750,00');
      expect(card().used.format(), r'R$ 1.250,00');
      expect(card().limit.format(), r'R$ 5.000,00');
    });

    test('usage ratio goes from 0 to 1 for the progress bar', () {
      expect(card(usedCents: 0).usageRatio, 0);
      expect(card().usageRatio, 0.25);
      expect(card(usedCents: 500000).usageRatio, 1);
    });

    test('knows when the card is over its limit', () {
      expect(card().isOverLimit, isFalse);
      expect(card(usedCents: 500000).isOverLimit, isFalse);
      expect(card(usedCents: 500001).isOverLimit, isTrue);
      expect(card(usedCents: 600000).availableCents, -100000);
    });

    test('a zero limit never divides by zero', () {
      expect(card(limitCents: 0, usedCents: 100).usageRatio, 0);
    });
  });

  group('InvoiceEntity', () {
    InvoiceEntity invoice(InvoiceStatus status, int totalCents) {
      return InvoiceEntity(
        id: 'i1',
        accountId: 'a1',
        referenceMonth: DateTime(2026, 3),
        periodStart: DateTime(2026, 2, 11),
        periodEnd: DateTime(2026, 3, 10),
        dueDate: DateTime(2026, 3, 17),
        status: status,
        totalCents: totalCents,
      );
    }

    test('only an unpaid invoice with a total needs payment', () {
      expect(invoice(InvoiceStatus.closed, 10000).needsPayment, isTrue);
      expect(invoice(InvoiceStatus.open, 10000).needsPayment, isTrue);
      expect(invoice(InvoiceStatus.paid, 10000).needsPayment, isFalse);
      expect(invoice(InvoiceStatus.closed, 0).needsPayment, isFalse);
    });

    test('knows whether it is paid', () {
      expect(invoice(InvoiceStatus.paid, 0).isPaid, isTrue);
      expect(invoice(InvoiceStatus.open, 0).isPaid, isFalse);
    });
  });
}