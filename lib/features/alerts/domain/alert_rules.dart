import 'package:finly/features/alerts/domain/entities/app_alert.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

/// A pending bill is "due soon" from tomorrow up to this many days ahead.
const int dueSoonDays = 3;

/// The budgets at 80% of their limit or more (SRS FR-B02/B03). Under 80% there
/// is no alert.
List<AppAlert> budgetAlerts(List<BudgetProgress> items) {
  final alerts = <AppAlert>[];
  for (final item in items) {
    if (item.limitCents <= 0) continue;
    final level = item.level;
    if (level == BudgetLevel.normal) continue;

    alerts.add(
      AppAlert(
        kind: level == BudgetLevel.over
            ? AlertKind.budgetOver
            : AlertKind.budgetNear,
        subject: item.category.name,
        currency: item.currency,
        amountCents: item.spentCents,
        limitCents: item.limitCents,
        // Whole cents, no floating point: 12345 of 10000 is 123%.
        percent: item.spentCents * 100 ~/ item.limitCents,
      ),
    );
  }
  return alerts;
}

/// The pending expenses that are overdue, due today, or due in the next
/// [soonDays] days. Only the date counts, not the time of day. Incomes,
/// confirmed or failed entries and transfers are not bills.
List<AppAlert> billAlerts(
  List<TransactionEntity> pending,
  DateTime today, {
  int soonDays = dueSoonDays,
}) {
  // UTC dates, so a daylight saving change never shifts a day.
  final todayDay = DateTime.utc(today.year, today.month, today.day);

  final alerts = <AppAlert>[];
  for (final bill in pending) {
    if (bill.type != TransactionType.expense) continue;
    if (bill.status != TransactionStatus.pending) continue;

    final due = DateTime(
      bill.occurredAt.year,
      bill.occurredAt.month,
      bill.occurredAt.day,
    );
    final days = DateTime.utc(due.year, due.month, due.day)
        .difference(todayDay)
        .inDays;
    if (days > soonDays) continue;

    alerts.add(
      AppAlert(
        kind: days < 0
            ? AlertKind.billOverdue
            : (days == 0 ? AlertKind.billDueToday : AlertKind.billDueSoon),
        subject: bill.description,
        currency: bill.currency,
        amountCents: bill.amountCents,
        dueDate: due,
        daysUntilDue: days,
      ),
    );
  }
  return alerts;
}

/// Most urgent first: overdue bills, budgets over the limit, bills due today,
/// budgets near the limit, bills due soon. Inside each group: the oldest or
/// soonest bill first, and the most used budget first.
List<AppAlert> sortAlerts(List<AppAlert> alerts) {
  final sorted = [...alerts];
  sorted.sort((a, b) {
    final byKind = a.kind.index.compareTo(b.kind.index);
    if (byKind != 0) return byKind;

    final int within;
    if (a.isBudget) {
      within = (b.percent ?? 0).compareTo(a.percent ?? 0);
    } else {
      within = (a.daysUntilDue ?? 0).compareTo(b.daysUntilDue ?? 0);
    }
    return within != 0 ? within : a.subject.compareTo(b.subject);
  });
  return sorted;
}