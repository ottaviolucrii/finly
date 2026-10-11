import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_status.dart';
import 'package:finly/features/cards/presentation/card_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 11);

  InvoiceEntity invoice(
    String id, {
    required DateTime month,
    InvoiceStatus status = InvoiceStatus.open,
    int total = 100000,
    int paid = 0,
  }) {
    return InvoiceEntity(
      id: id,
      accountId: 'card',
      referenceMonth: month,
      periodStart: DateTime(month.year, month.month - 1, 11),
      periodEnd: DateTime(month.year, month.month, 10),
      dueDate: DateTime(month.year, month.month, 17),
      status: status,
      totalCents: total,
      paidCents: paid,
    );
  }

  group('invoiceTitle and invoiceMonthLabel', () {
    test('this year: only the month', () {
      final october = invoice('i1', month: DateTime(2026, 10));
      expect(invoiceTitle(october, today), 'Fatura de outubro');
      expect(invoiceMonthLabel(october, today), 'Outubro');
    });

    test('another year: the year too', () {
      final december = invoice('i1', month: DateTime(2025, 12));
      expect(invoiceTitle(december, today), 'Fatura de dezembro de 2025');
      expect(invoiceMonthLabel(december, today), 'Dezembro de 2025');
    });

    test('a month with an accent', () {
      expect(invoiceMonthLabel(invoice('i1', month: DateTime(2026, 3)), today), 'Março');
    });
  });

  group('currentInvoice', () {
    test('the open one when nothing is left to pay', () {
      // November closes on 10/11, so it is open on 11/10.
      final november = invoice('nov', month: DateTime(2026, 11));
      final september = invoice('sep', month: DateTime(2026, 9), status: InvoiceStatus.paid, paid: 100000);

      expect(currentInvoice([november, september], today), november);
    });

    test('a closed one still to pay comes before the open one', () {
      final november = invoice('nov', month: DateTime(2026, 11));
      // October closed on 10/10 and is not paid.
      final october = invoice('oct', month: DateTime(2026, 10));

      expect(currentInvoice([november, october], today), october);
    });

    test('of two still to pay, the one due first', () {
      final october = invoice('oct', month: DateTime(2026, 10), status: InvoiceStatus.closed);
      final september = invoice('sep', month: DateTime(2026, 9), status: InvoiceStatus.closed);

      expect(currentInvoice([october, september], today), september);
    });

    test('one paid in part is still to pay', () {
      final november = invoice('nov', month: DateTime(2026, 11));
      final october = invoice('oct', month: DateTime(2026, 10), status: InvoiceStatus.closed, paid: 40000);

      expect(currentInvoice([november, october], today), october);
    });

    test('with invoices open ahead of time, the current one (closing first)', () {
      // An installment purchase made the next invoices exist already: all
      // open. Newest first, like the list comes.
      final february = invoice('feb', month: DateTime(2027, 2));
      final january = invoice('jan', month: DateTime(2027, 1));
      final december = invoice('dec', month: DateTime(2026, 12));
      final november = invoice('nov', month: DateTime(2026, 11));

      expect(currentInvoice([february, january, december, november], today), november);
    });

    test('once the current one is paid, the next one', () {
      final january = invoice('jan', month: DateTime(2027, 1));
      final december = invoice('dec', month: DateTime(2026, 12));
      final november = invoice('nov', month: DateTime(2026, 11), status: InvoiceStatus.paid, paid: 100000);
      final october = invoice('oct', month: DateTime(2026, 10), status: InvoiceStatus.paid, paid: 100000);

      expect(currentInvoice([january, december, november, october], today), december);
    });

    test('a closed one with nothing in it is not to pay', () {
      final october = invoice('oct', month: DateTime(2026, 10), status: InvoiceStatus.closed, total: 0);

      expect(currentInvoice([october], today), isNull);
    });

    test('no invoices, none', () {
      expect(currentInvoice(const [], today), isNull);
    });
  });

  group('invoiceTone', () {
    test('open is blue, to pay is gold, paid is green', () {
      expect(invoiceTone(invoice('nov', month: DateTime(2026, 11)), today), InvoiceTone.open);
      expect(invoiceTone(invoice('oct', month: DateTime(2026, 10)), today), InvoiceTone.toPay);
      expect(invoiceTone(invoice('sep', month: DateTime(2026, 9), status: InvoiceStatus.paid, paid: 100000), today), InvoiceTone.paid);
    });

    test('paid in part is gold even while open', () {
      expect(invoiceTone(invoice('nov', month: DateTime(2026, 11), paid: 1000), today), InvoiceTone.toPay);
    });
  });

  group('cardIndexToPay', () {
    CreditCardEntity card(String id) => CreditCardEntity(
          accountId: id,
          workspaceId: 'w1',
          name: id,
          currency: 'BRL',
          limitCents: 500000,
          closingDay: 10,
          dueDay: 17,
          usedCents: 0,
        );

    final cards = [card('nubank'), card('itau'), card('inter')];

    test('the first card when nothing is to pay', () {
      expect(cardIndexToPay(cards, {'nubank': [invoice('nov', month: DateTime(2026, 11))]}, today), 0);
    });

    test('the card with a closed invoice to pay', () {
      final byCard = {
        'nubank': [invoice('n', month: DateTime(2026, 11))],
        'itau': [invoice('i', month: DateTime(2026, 10))],
      };
      expect(cardIndexToPay(cards, byCard, today), 1);
    });

    test('of two to pay, the one due first', () {
      final byCard = {
        'itau': [invoice('i', month: DateTime(2026, 10), status: InvoiceStatus.closed)],
        'inter': [invoice('x', month: DateTime(2026, 9), status: InvoiceStatus.closed)],
      };
      expect(cardIndexToPay(cards, byCard, today), 2);
    });

    test('a card paid in part still counts', () {
      final byCard = {
        'inter': [invoice('x', month: DateTime(2026, 11), paid: 1000)],
      };
      expect(cardIndexToPay(cards, byCard, today), 2);
    });

    test('a card whose invoices did not load is skipped', () {
      expect(cardIndexToPay(cards, const {}, today), 0);
    });
  });
}
