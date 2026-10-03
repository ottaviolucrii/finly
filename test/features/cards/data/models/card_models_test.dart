import 'package:finly/features/cards/data/models/credit_card_model.dart';
import 'package:finly/features/cards/data/models/invoice_model.dart';
import 'package:finly/features/cards/domain/entities/invoice_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const account = {
    'id': 'a1',
    'workspace_id': 'w1',
    'name': 'Nubank',
    'currency': 'BRL',
  };
  const details = {
    'account_id': 'a1',
    'limit_cents': 500000,
    'closing_day': 10,
    'due_day': 17,
  };

  group('CreditCardModel', () {
    test('combines the account, its settings and its balance', () {
      final model = CreditCardModel.fromMaps(
        account: account,
        details: details,
        balance: const {'projected_balance_cents': -125000},
      );

      expect(model.accountId, 'a1');
      expect(model.workspaceId, 'w1');
      expect(model.name, 'Nubank');
      expect(model.currency, 'BRL');
      expect(model.limitCents, 500000);
      expect(model.closingDay, 10);
      expect(model.dueDay, 17);
      expect(model.usedCents, 125000);
      expect(model.availableCents, 375000);
    });

    test('a positive balance (refunds) means no debt', () {
      final model = CreditCardModel.fromMaps(
        account: account,
        details: details,
        balance: const {'projected_balance_cents': 3000},
      );

      expect(model.usedCents, 0);
    });

    test('a card without a balance row has no debt', () {
      final model = CreditCardModel.fromMaps(account: account, details: details);

      expect(model.usedCents, 0);
    });

    test('reads numbers that arrive as doubles', () {
      final model = CreditCardModel.fromMaps(
        account: account,
        details: const {
          'account_id': 'a1',
          'limit_cents': 500000.0,
          'closing_day': 10.0,
          'due_day': 17.0,
        },
        balance: const {'projected_balance_cents': -100.0},
      );

      expect(model.limitCents, 500000);
      expect(model.closingDay, 10);
      expect(model.usedCents, 100);
    });
  });

  group('InvoiceModel', () {
    const row = {
      'id': 'i1',
      'account_id': 'a1',
      'reference_month': '2026-03-01',
      'period_start': '2026-02-11',
      'period_end': '2026-03-10',
      'due_date': '2026-03-17',
      'status': 'closed',
    };

    test('reads the dates, the status and the total', () {
      final model = InvoiceModel.fromMap(row, totalCents: 10000);

      expect(model.id, 'i1');
      expect(model.accountId, 'a1');
      expect(model.referenceMonth, DateTime(2026, 3));
      expect(model.periodStart, DateTime(2026, 2, 11));
      expect(model.periodEnd, DateTime(2026, 3, 10));
      expect(model.dueDate, DateTime(2026, 3, 17));
      expect(model.status, InvoiceStatus.closed);
      expect(model.totalCents, 10000);
    });

    test('an invoice with no charges has a zero total', () {
      expect(InvoiceModel.fromMap(row).totalCents, 0);
    });

    test('an unknown status fails loudly instead of guessing', () {
      expect(
        () => InvoiceModel.fromMap({...row, 'status': 'overdue'}),
        throwsArgumentError,
      );
    });
  });
}