import 'package:finly/features/alerts/domain/alert_rules.dart';
import 'package:finly/features/alerts/domain/entities/app_alert.dart';
import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BudgetProgress progress({
    String name = 'Alimentação',
    required int spent,
    int limit = 100000,
    String currency = 'BRL',
  }) {
    return BudgetProgress(
      budget: BudgetEntity(
        id: 'b1',
        workspaceId: 'w1',
        categoryId: 'c1',
        effectiveFrom: DateTime(2026, 10),
        limitCents: limit,
        currency: currency,
      ),
      category: CategoryEntity(
        id: 'c1',
        workspaceId: 'w1',
        name: name,
        kind: CategoryKind.expense,
        icon: 'restaurant',
        colorHex: '#F29D38',
        isDefault: true,
      ),
      spentCents: spent,
    );
  }

  final today = DateTime(2026, 10, 6, 15, 30);

  TransactionEntity bill({
    String id = 't1',
    required DateTime on,
    String description = 'Aluguel',
    TransactionType type = TransactionType.expense,
    TransactionStatus status = TransactionStatus.pending,
    int cents = 150000,
  }) {
    return TransactionEntity(
      id: id,
      workspaceId: 'w1',
      accountId: 'a1',
      categoryId: null,
      type: type,
      status: status,
      amountCents: cents,
      currency: 'BRL',
      description: description,
      occurredAt: on,
    );
  }

  group('budgetAlerts', () {
    test('has no alert under 80%', () {
      expect(budgetAlerts([progress(spent: 79999)]), isEmpty);
      expect(budgetAlerts([progress(spent: 0)]), isEmpty);
    });

    test('warns from exactly 80%', () {
      final alerts = budgetAlerts([progress(spent: 80000)]);

      expect(alerts.single.kind, AlertKind.budgetNear);
      expect(alerts.single.percent, 80);
    });

    test('warns up to the limit', () {
      final alerts = budgetAlerts([progress(spent: 99000)]);

      expect(alerts.single.kind, AlertKind.budgetNear);
      expect(alerts.single.percent, 99);
    });

    test('exactly at the limit is still a warning, at 100%', () {
      final alerts = budgetAlerts([progress(spent: 100000)]);

      expect(alerts.single.kind, AlertKind.budgetNear);
      expect(alerts.single.percent, 100);
    });

    test('above the limit is over the budget', () {
      final alerts = budgetAlerts([progress(spent: 123456)]);

      expect(alerts.single.kind, AlertKind.budgetOver);
      expect(alerts.single.percent, 123);
    });

    test('carries the category, the amounts and the currency', () {
      final alert = budgetAlerts([
        progress(name: 'Lazer', spent: 90000, limit: 100000, currency: 'USD'),
      ]).single;

      expect(alert.subject, 'Lazer');
      expect(alert.amountCents, 90000);
      expect(alert.limitCents, 100000);
      expect(alert.currency, 'USD');
      expect(alert.dueDate, isNull);
    });

    test('ignores a budget with no limit', () {
      expect(budgetAlerts([progress(spent: 500, limit: 0)]), isEmpty);
    });

    test('lists one alert per budget that needs one', () {
      final alerts = budgetAlerts([
        progress(name: 'A', spent: 10000),
        progress(name: 'B', spent: 85000),
        progress(name: 'C', spent: 150000),
      ]);

      expect(alerts.map((a) => a.subject), ['B', 'C']);
    });
  });

  group('billAlerts', () {
    test('a past date is overdue', () {
      final alert = billAlerts([bill(on: DateTime(2026, 10, 4, 12))], today).single;

      expect(alert.kind, AlertKind.billOverdue);
      expect(alert.daysUntilDue, -2);
      expect(alert.dueDate, DateTime(2026, 10, 4));
    });

    test('today is due today, whatever the time of day', () {
      expect(
        billAlerts([bill(on: DateTime(2026, 10, 6, 0, 5))], today).single.kind,
        AlertKind.billDueToday,
      );
      expect(
        billAlerts([bill(on: DateTime(2026, 10, 6, 23, 59))], today).single.kind,
        AlertKind.billDueToday,
      );
    });

    test('tomorrow just after midnight is due soon, in 1 day', () {
      final alert = billAlerts([bill(on: DateTime(2026, 10, 7, 0, 10))], today).single;

      expect(alert.kind, AlertKind.billDueSoon);
      expect(alert.daysUntilDue, 1);
    });

    test('the third day ahead is still due soon', () {
      final alert = billAlerts([bill(on: DateTime(2026, 10, 9, 12))], today).single;

      expect(alert.kind, AlertKind.billDueSoon);
      expect(alert.daysUntilDue, 3);
    });

    test('the fourth day ahead is not reported yet', () {
      expect(billAlerts([bill(on: DateTime(2026, 10, 10, 12))], today), isEmpty);
    });

    test('counts days across the end of a month', () {
      final alert = billAlerts(
        [bill(on: DateTime(2026, 11, 1, 12))],
        DateTime(2026, 10, 30, 10),
      ).single;

      expect(alert.daysUntilDue, 2);
    });

    test('ignores incomes', () {
      expect(
        billAlerts([bill(on: DateTime(2026, 10, 4), type: TransactionType.income)], today),
        isEmpty,
      );
    });

    test('ignores entries that are not pending', () {
      expect(
        billAlerts([bill(on: DateTime(2026, 10, 4), status: TransactionStatus.posted)], today),
        isEmpty,
      );
      expect(
        billAlerts([bill(on: DateTime(2026, 10, 4), status: TransactionStatus.failed)], today),
        isEmpty,
      );
    });

    test('ignores transfer legs', () {
      expect(
        billAlerts([bill(on: DateTime(2026, 10, 4), type: TransactionType.transferOut)], today),
        isEmpty,
      );
    });

    test('carries the description, the amount and the currency', () {
      final alert = billAlerts(
        [bill(on: DateTime(2026, 10, 6), description: 'Internet', cents: 9990)],
        today,
      ).single;

      expect(alert.subject, 'Internet');
      expect(alert.amountCents, 9990);
      expect(alert.currency, 'BRL');
      expect(alert.limitCents, isNull);
      expect(alert.percent, isNull);
    });
  });

  group('sortAlerts', () {
    AppAlert alert(
      AlertKind kind, {
      String subject = 'x',
      int? percent,
      int? days,
    }) {
      return AppAlert(
        kind: kind,
        subject: subject,
        currency: 'BRL',
        amountCents: 100,
        percent: percent,
        daysUntilDue: days,
      );
    }

    test('puts the most urgent kind first', () {
      final sorted = sortAlerts([
        alert(AlertKind.billDueSoon, days: 2),
        alert(AlertKind.budgetNear, percent: 90),
        alert(AlertKind.billDueToday, days: 0),
        alert(AlertKind.budgetOver, percent: 120),
        alert(AlertKind.billOverdue, days: -1),
      ]);

      expect(sorted.map((a) => a.kind), [
        AlertKind.billOverdue,
        AlertKind.budgetOver,
        AlertKind.billDueToday,
        AlertKind.budgetNear,
        AlertKind.billDueSoon,
      ]);
    });

    test('lists the oldest overdue bill first', () {
      final sorted = sortAlerts([
        alert(AlertKind.billOverdue, subject: 'recent', days: -1),
        alert(AlertKind.billOverdue, subject: 'old', days: -9),
      ]);

      expect(sorted.map((a) => a.subject), ['old', 'recent']);
    });

    test('lists the most used budget first', () {
      final sorted = sortAlerts([
        alert(AlertKind.budgetNear, subject: 'a', percent: 82),
        alert(AlertKind.budgetNear, subject: 'b', percent: 97),
      ]);

      expect(sorted.map((a) => a.subject), ['b', 'a']);
    });

    test('lists the soonest bill first', () {
      final sorted = sortAlerts([
        alert(AlertKind.billDueSoon, subject: 'later', days: 3),
        alert(AlertKind.billDueSoon, subject: 'sooner', days: 1),
      ]);

      expect(sorted.map((a) => a.subject), ['sooner', 'later']);
    });

    test('breaks a tie by name, so the order never jumps around', () {
      final sorted = sortAlerts([
        alert(AlertKind.billDueToday, subject: 'b', days: 0),
        alert(AlertKind.billDueToday, subject: 'a', days: 0),
      ]);

      expect(sorted.map((a) => a.subject), ['a', 'b']);
    });

    test('does not change the list it is given', () {
      final original = [
        alert(AlertKind.billDueSoon, days: 2),
        alert(AlertKind.billOverdue, days: -1),
      ];

      sortAlerts(original);

      expect(original.first.kind, AlertKind.billDueSoon);
    });
  });

  group('AppAlert', () {
    test('overdue, over budget and due today are urgent', () {
      const base = AppAlert(
        kind: AlertKind.billOverdue,
        subject: 'x',
        currency: 'BRL',
        amountCents: 1,
      );

      expect(base.isUrgent, isTrue);
      expect(
        AppAlert(kind: AlertKind.budgetOver, subject: 'x', currency: 'BRL', amountCents: 1).isUrgent,
        isTrue,
      );
      expect(
        AppAlert(kind: AlertKind.billDueToday, subject: 'x', currency: 'BRL', amountCents: 1).isUrgent,
        isTrue,
      );
    });

    test('near the limit and due soon are warnings', () {
      expect(
        AppAlert(kind: AlertKind.budgetNear, subject: 'x', currency: 'BRL', amountCents: 1).isUrgent,
        isFalse,
      );
      expect(
        AppAlert(kind: AlertKind.billDueSoon, subject: 'x', currency: 'BRL', amountCents: 1).isUrgent,
        isFalse,
      );
    });
  });
}