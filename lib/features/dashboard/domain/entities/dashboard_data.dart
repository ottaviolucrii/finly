import 'package:equatable/equatable.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';

/// What the user has in one currency (credit cards are not part of it).
class CurrencyBalance extends Equatable {
  final String currency;

  /// Opening balances plus posted transactions.
  final int postedCents;

  /// Posted plus pending transactions.
  final int projectedCents;

  /// What is owed on credit cards in this currency (never negative).
  final int cardDebtCents;

  const CurrencyBalance({
    required this.currency,
    required this.postedCents,
    required this.projectedCents,
    required this.cardDebtCents,
  });

  bool get hasPendingEffect => projectedCents != postedCents;

  Money get posted => Money(postedCents, currency);
  Money get projected => Money(projectedCents, currency);
  Money get cardDebt => Money(cardDebtCents, currency);

  @override
  List<Object?> get props =>
      [currency, postedCents, projectedCents, cardDebtCents];
}

/// Income and expenses of the month in one currency, split into what already
/// happened (posted) and what is still expected (pending).
class CurrencyFlow extends Equatable {
  final String currency;
  final int incomePostedCents;
  final int incomePendingCents;
  final int expensePostedCents;
  final int expensePendingCents;

  const CurrencyFlow({
    required this.currency,
    required this.incomePostedCents,
    required this.incomePendingCents,
    required this.expensePostedCents,
    required this.expensePendingCents,
  });

  /// Income minus expenses that already happened. Negative when spending
  /// exceeds income.
  int get resultPostedCents => incomePostedCents - expensePostedCents;

  bool get hasPending => incomePendingCents > 0 || expensePendingCents > 0;

  Money money(int cents) => Money(cents, currency);

  @override
  List<Object?> get props => [
        currency,
        incomePostedCents,
        incomePendingCents,
        expensePostedCents,
        expensePendingCents,
      ];
}

/// Everything the home screen shows for one workspace.
class DashboardData extends Equatable {
  /// First day of the month the flow refers to.
  final DateTime month;
  final int accountCount;
  final List<CurrencyBalance> balances;
  final List<CurrencyFlow> flows;

  /// The budgets closest to their limit (up to 3).
  final List<BudgetProgress> budgets;

  /// Pending items from the last 30 days to the next 14, oldest first.
  final List<TransactionEntity> upcoming;

  const DashboardData({
    required this.month,
    required this.accountCount,
    required this.balances,
    required this.flows,
    required this.budgets,
    required this.upcoming,
  });

  bool get hasAccounts => accountCount > 0;

  @override
  List<Object?> get props =>
      [month, accountCount, balances, flows, budgets, upcoming];
}