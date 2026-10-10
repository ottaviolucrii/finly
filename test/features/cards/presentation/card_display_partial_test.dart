import 'package:finly/core/money/money.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_status.dart';
import 'package:finly/features/cards/domain/payment_amount.dart';
import 'package:finly/features/cards/presentation/card_messages.dart';
import 'package:finly/features/cards/presentation/card_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 3, 12);

  InvoiceEntity build({int paid = 0, InvoiceStatus status = InvoiceStatus.closed}) {
    return InvoiceEntity(
      id: 'i1',
      accountId: 'card1',
      referenceMonth: DateTime(2026, 3),
      periodStart: DateTime(2026, 2, 11),
      periodEnd: DateTime(2026, 3, 10),
      dueDate: DateTime(2026, 3, 17),
      status: status,
      totalCents: 10000,
      paidCents: paid,
    );
  }

  group('invoiceDisplayLabel', () {
    test('says "Parcialmente paga" when part was paid', () {
      expect(invoiceDisplayLabel(build(paid: 4000), today), 'Parcialmente paga');
    });

    test('says "Fechada" for a closed invoice with no payment', () {
      expect(invoiceDisplayLabel(build(), today), 'Fechada');
    });

    test('says "Aberta" for an open invoice that is still in its cycle', () {
      final open = InvoiceEntity(
        id: 'i2',
        accountId: 'card1',
        referenceMonth: DateTime(2026, 3),
        periodStart: DateTime(2026, 3, 11),
        periodEnd: DateTime(2026, 4, 10),
        dueDate: DateTime(2026, 4, 17),
        status: InvoiceStatus.open,
        totalCents: 500,
      );

      expect(invoiceDisplayLabel(open, today), 'Aberta');
    });

    test('says "Paga" once it is settled', () {
      expect(
        invoiceDisplayLabel(build(paid: 10000, status: InvoiceStatus.paid), today),
        'Paga',
      );
    });

    test('still follows the day for an open invoice whose cycle ended', () {
      expect(invoiceDisplayLabel(build(status: InvoiceStatus.open), today), 'Fechada');
    });
  });

  group('invoiceDisplayIcon', () {
    test('is its own icon for a partly paid invoice', () {
      expect(invoiceDisplayIcon(build(paid: 4000), today), Icons.timelapse);
    });

    test('is the icon of the status otherwise', () {
      expect(invoiceDisplayIcon(build(), today), Icons.lock_outline);
      expect(
        invoiceDisplayIcon(build(paid: 10000, status: InvoiceStatus.paid), today),
        Icons.check_circle_outline,
      );
    });
  });

  group('cardFailureMessage for a payment', () {
    test('an amount above what is owed', () {
      expect(
        cardFailureMessage(const RuleFailure('payment amount is above what is owed')),
        'O valor é maior do que falta pagar.',
      );
    });

    test('an amount that is not positive', () {
      expect(
        cardFailureMessage(const RuleFailure('payment amount must be positive')),
        'Informe um valor maior que zero.',
      );
      expect(
        cardFailureMessage(const ValidationFailure('invalid_payment_amount')),
        'Informe um valor maior que zero.',
      );
    });

    test('the messages that already existed are unchanged', () {
      expect(cardFailureMessage(const RuleFailure('invoice already paid')), 'Esta fatura já foi paga.');
      expect(
        cardFailureMessage(const RuleFailure('nothing to pay on this invoice')),
        'Esta fatura não tem nada a pagar.',
      );
    });
  });

  group('paymentAmountMessage', () {
    const remaining = Money(33335, 'BRL');

    test('says nothing for an empty field', () {
      expect(paymentAmountMessage(PaymentAmountProblem.empty, remaining), isNull);
    });

    test('explains the format when it is not an amount', () {
      expect(
        paymentAmountMessage(PaymentAmountProblem.invalid, remaining),
        'Valor inválido. Use o formato 1.234,56.',
      );
    });

    test('asks for more than zero', () {
      expect(
        paymentAmountMessage(PaymentAmountProblem.notPositive, remaining),
        'Informe um valor maior que zero.',
      );
    });

    test('says how much is owed when the amount is too high', () {
      expect(
        paymentAmountMessage(PaymentAmountProblem.aboveOwed, remaining),
        'O valor é maior do que falta pagar (R\$ 333,35).',
      );
    });
  });
}
