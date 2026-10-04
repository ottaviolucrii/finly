import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_status.dart';
import 'package:finly/features/cards/presentation/card_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CreditCardEntity card(int limitCents, int usedCents) {
    return CreditCardEntity(
      accountId: 'a1',
      workspaceId: 'w1',
      name: 'Nubank',
      currency: 'BRL',
      limitCents: limitCents,
      closingDay: 10,
      dueDay: 17,
      usedCents: usedCents,
    );
  }

  group('cardUsageLevel', () {
    test('is normal below 80% of the limit', () {
      expect(cardUsageLevel(card(100000, 0)), CardUsageLevel.normal);
      expect(cardUsageLevel(card(100000, 79999)), CardUsageLevel.normal);
    });

    test('is a warning from 80% up to and including 100%', () {
      expect(cardUsageLevel(card(100000, 80000)), CardUsageLevel.warning);
      expect(cardUsageLevel(card(100000, 100000)), CardUsageLevel.warning);
    });

    test('is over the limit above 100%', () {
      expect(cardUsageLevel(card(100000, 100001)), CardUsageLevel.over);
    });

    test('a zero limit is only over when there is debt', () {
      expect(cardUsageLevel(card(0, 0)), CardUsageLevel.normal);
      expect(cardUsageLevel(card(0, 100)), CardUsageLevel.over);
    });
  });

  group('cardUsageLabel', () {
    test('says nothing when all is fine and warns in words otherwise', () {
      expect(cardUsageLabel(CardUsageLevel.normal), isNull);
      expect(cardUsageLabel(CardUsageLevel.warning), 'Perto do limite');
      expect(cardUsageLabel(CardUsageLevel.over), 'Acima do limite');
    });
  });

  group('invoice status', () {
    test('has a label in Portuguese', () {
      expect(invoiceStatusLabel(InvoiceStatus.open), 'Aberta');
      expect(invoiceStatusLabel(InvoiceStatus.closed), 'Fechada');
      expect(invoiceStatusLabel(InvoiceStatus.paid), 'Paga');
    });

    test('has an icon', () {
      expect(invoiceStatusIcon(InvoiceStatus.open), Icons.schedule);
      expect(invoiceStatusIcon(InvoiceStatus.closed), Icons.lock_outline);
      expect(invoiceStatusIcon(InvoiceStatus.paid), Icons.check_circle_outline);
    });
  });
}