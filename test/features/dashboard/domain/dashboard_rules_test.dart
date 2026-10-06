import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/dashboard/domain/dashboard_rules.dart';
import 'package:finly/features/dashboard/domain/entities/cash_flow_entry.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AccountEntity account(
    String id,
    AccountType type,
    String currency,
    int posted,
    int projected,
  ) {
    return AccountEntity(
      id: id,
      workspaceId: 'w1',
      name: id,
      type: type,
      currency: currency,
      openingBalanceCents: 0,
      postedBalanceCents: posted,
      projectedBalanceCents: projected,
    );
  }

  CashFlowEntry entry(
    TransactionType type,
    TransactionStatus status,
    int cents, {
    String currency = 'BRL',
  }) {
    return CashFlowEntry(
      type: type,
      status: status,
      currency: currency,
      amountCents: cents,
    );
  }

  group('sortCurrencies', () {
    test('puts BRL first and the others in alphabetical order', () {
      expect(sortCurrencies(['USD', 'EUR', 'BRL']), ['BRL', 'EUR', 'USD']);
      expect(sortCurrencies(['USD', 'EUR']), ['EUR', 'USD']);
    });

    test('removes duplicates', () {
      expect(sortCurrencies(['BRL', 'BRL', 'USD']), ['BRL', 'USD']);
    });
  });

  group('totalsByCurrency', () {
    test('adds the accounts of each currency separately', () {
      final totals = totalsByCurrency([
        account('a', AccountType.checking, 'BRL', 100000, 90000),
        account('b', AccountType.savings, 'BRL', 50000, 50000),
        account('c', AccountType.checking, 'USD', 20000, 20000),
      ]);

      expect(totals.map((t) => t.currency), ['BRL', 'USD']);
      expect(totals[0].postedCents, 150000);
      expect(totals[0].projectedCents, 140000);
      expect(totals[0].hasPendingEffect, isTrue);
      expect(totals[1].postedCents, 20000);
      expect(totals[1].hasPendingEffect, isFalse);
    });

    test('credit cards are not part of the balance but their debt is shown',
        () {
      final totals = totalsByCurrency([
        account('a', AccountType.checking, 'BRL', 100000, 100000),
        account('card', AccountType.creditCard, 'BRL', -30000, -45000),
      ]);

      expect(totals.single.postedCents, 100000);
      expect(totals.single.projectedCents, 100000);
      expect(totals.single.cardDebtCents, 45000);
    });

    test('a card with a positive balance means no debt', () {
      final totals = totalsByCurrency([
        account('card', AccountType.creditCard, 'BRL', 2000, 2000),
      ]);

      expect(totals.single.cardDebtCents, 0);
    });

    test('a currency that only has a card still appears, with zero balance',
        () {
      final totals = totalsByCurrency([
        account('card', AccountType.creditCard, 'USD', -1000, -1000),
      ]);

      expect(totals.single.currency, 'USD');
      expect(totals.single.postedCents, 0);
      expect(totals.single.cardDebtCents, 1000);
    });

    test('no accounts gives no totals', () {
      expect(totalsByCurrency(const []), isEmpty);
    });
  });

  group('aggregateFlow', () {
    test('splits income and expenses into posted and pending', () {
      final flows = aggregateFlow([
        entry(TransactionType.income, TransactionStatus.posted, 500000),
        entry(TransactionType.income, TransactionStatus.pending, 100000),
        entry(TransactionType.expense, TransactionStatus.posted, 120000),
        entry(TransactionType.expense, TransactionStatus.posted, 30000),
        entry(TransactionType.expense, TransactionStatus.pending, 80000),
      ]);

      final flow = flows.single;
      expect(flow.incomePostedCents, 500000);
      expect(flow.incomePendingCents, 100000);
      expect(flow.expensePostedCents, 150000);
      expect(flow.expensePendingCents, 80000);
      expect(flow.resultPostedCents, 350000);
      expect(flow.hasPending, isTrue);
    });

    test('failed entries and transfers do not count', () {
      final flows = aggregateFlow([
        entry(TransactionType.expense, TransactionStatus.failed, 99999),
        entry(TransactionType.transferOut, TransactionStatus.posted, 50000),
        entry(TransactionType.transferIn, TransactionStatus.posted, 50000),
        entry(TransactionType.income, TransactionStatus.posted, 1000),
      ]);

      expect(flows.single.incomePostedCents, 1000);
      expect(flows.single.expensePostedCents, 0);
    });

    test('currencies are kept apart and sorted, BRL first', () {
      final flows = aggregateFlow([
        entry(TransactionType.expense, TransactionStatus.posted, 5000,
            currency: 'USD'),
        entry(TransactionType.expense, TransactionStatus.posted, 100),
      ]);

      expect(flows.map((f) => f.currency), ['BRL', 'USD']);
      expect(flows[0].expensePostedCents, 100);
      expect(flows[1].expensePostedCents, 5000);
    });

    test('the result is negative when spending is higher than income', () {
      final flows = aggregateFlow([
        entry(TransactionType.income, TransactionStatus.posted, 1000),
        entry(TransactionType.expense, TransactionStatus.posted, 3000),
      ]);

      expect(flows.single.resultPostedCents, -2000);
      expect(flows.single.money(flows.single.resultPostedCents).isNegative, isTrue);
    });

    test('no entries gives no flow', () {
      expect(aggregateFlow(const []), isEmpty);
    });
  });
}