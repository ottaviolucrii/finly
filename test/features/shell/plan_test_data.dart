import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/forecast/domain/entities/forecast_items.dart';
import 'package:finly/features/goals/domain/entities/goal.dart';
import 'package:finly/features/goals/domain/entities/goal_progress.dart';

/// A forecast that starts on [from] and has one point per day with [balances].
Forecast forecastOf(DateTime from, List<int> balances, {String currency = 'BRL'}) {
  return Forecast(
    currency: currency,
    startCents: balances.first,
    points: [
      for (var i = 0; i < balances.length; i++)
        ForecastPoint(date: DateTime(from.year, from.month, from.day + i), balanceCents: balances[i]),
    ],
    events: const [],
  );
}

BudgetProgress budgetOf(String name, int spent, int limit, {String currency = 'BRL'}) {
  return BudgetProgress(
    budget: BudgetEntity(
      id: name,
      workspaceId: 'w1',
      categoryId: name,
      effectiveFrom: DateTime(2026, 10),
      limitCents: limit,
      currency: currency,
    ),
    category: CategoryEntity(
      id: name,
      workspaceId: 'w1',
      name: name,
      kind: CategoryKind.expense,
      icon: 'category',
      colorHex: '#1060E3',
      isDefault: false,
    ),
    spentCents: spent,
  );
}

GoalProgress goalOf(String name, {int balance = 960000, int target = 1500000}) {
  return GoalProgress(
    goal: Goal(id: name, workspaceId: 'w1', accountId: 'a1', currency: 'BRL', name: name, targetCents: target),
    accountName: 'Poupança',
    balanceCents: balance,
  );
}
