import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/dashboard/domain/entities/cash_flow_entry.dart';
import 'package:finly/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

/// BRL first, then the other currencies alphabetically.
List<String> sortCurrencies(Iterable<String> currencies) {
  final list = currencies.toSet().toList()
    ..sort((a, b) {
      if (a == 'BRL') return b == 'BRL' ? 0 : -1;
      if (b == 'BRL') return 1;
      return a.compareTo(b);
    });
  return list;
}

/// Totals per currency. Credit cards are not part of the balance: what is
/// owed on them is reported separately as [CurrencyBalance.cardDebtCents].
List<CurrencyBalance> totalsByCurrency(List<AccountEntity> accounts) {
  final posted = <String, int>{};
  final projected = <String, int>{};
  final debt = <String, int>{};

  for (final account in accounts) {
    final currency = account.currency;
    posted.putIfAbsent(currency, () => 0);
    projected.putIfAbsent(currency, () => 0);
    debt.putIfAbsent(currency, () => 0);

    if (account.type == AccountType.creditCard) {
      final owed = account.projectedBalanceCents < 0
          ? -account.projectedBalanceCents
          : 0;
      debt[currency] = debt[currency]! + owed;
      continue;
    }
    posted[currency] = posted[currency]! + account.postedBalanceCents;
    projected[currency] = projected[currency]! + account.projectedBalanceCents;
  }

  return [
    for (final currency in sortCurrencies(posted.keys))
      CurrencyBalance(
        currency: currency,
        postedCents: posted[currency]!,
        projectedCents: projected[currency]!,
        cardDebtCents: debt[currency]!,
      ),
  ];
}

/// Income and expenses per currency. Failed entries and transfers do not
/// count.
List<CurrencyFlow> aggregateFlow(List<CashFlowEntry> entries) {
  final incomePosted = <String, int>{};
  final incomePending = <String, int>{};
  final expensePosted = <String, int>{};
  final expensePending = <String, int>{};
  final currencies = <String>{};

  for (final entry in entries) {
    if (entry.status == TransactionStatus.failed) continue;
    final isIncome = entry.type == TransactionType.income;
    final isExpense = entry.type == TransactionType.expense;
    if (!isIncome && !isExpense) continue;

    final target = isIncome
        ? (entry.status == TransactionStatus.posted ? incomePosted : incomePending)
        : (entry.status == TransactionStatus.posted
            ? expensePosted
            : expensePending);
    target[entry.currency] = (target[entry.currency] ?? 0) + entry.amountCents;
    currencies.add(entry.currency);
  }

  return [
    for (final currency in sortCurrencies(currencies))
      CurrencyFlow(
        currency: currency,
        incomePostedCents: incomePosted[currency] ?? 0,
        incomePendingCents: incomePending[currency] ?? 0,
        expensePostedCents: expensePosted[currency] ?? 0,
        expensePendingCents: expensePending[currency] ?? 0,
      ),
  ];
}