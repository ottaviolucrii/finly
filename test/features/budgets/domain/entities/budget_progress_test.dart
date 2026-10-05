import 'package:finly/features/budgets/domain/entities/budget_entity.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const category = CategoryEntity(
    id: 'c1',
    workspaceId: 'w1',
    name: 'Alimentação',
    kind: CategoryKind.expense,
    icon: 'restaurant',
    colorHex: '#F29D38',
    isDefault: true,
  );

  BudgetProgress progress(int limit, int spent) {
    return BudgetProgress(
      budget: BudgetEntity(
        id: 'b1',
        workspaceId: 'w1',
        categoryId: 'c1',
        effectiveFrom: DateTime(2026, 3),
        limitCents: limit,
        currency: 'BRL',
      ),
      category: category,
      spentCents: spent,
    );
  }

  test('is normal below 80% of the limit', () {
    expect(progress(100000, 0).level, BudgetLevel.normal);
    expect(progress(100000, 79999).level, BudgetLevel.normal);
  });

  test('is a warning from 80% up to and including 100%', () {
    expect(progress(100000, 80000).level, BudgetLevel.warning);
    expect(progress(100000, 100000).level, BudgetLevel.warning);
  });

  test('is over the budget above 100%', () {
    expect(progress(100000, 100001).level, BudgetLevel.over);
  });

  test('knows what is left, and by how much it was exceeded', () {
    expect(progress(100000, 25000).remainingCents, 75000);
    expect(progress(100000, 25000).remaining.format(), r'R$ 750,00');
    expect(progress(100000, 120000).remainingCents, -20000);
  });

  test('the ratio is for the bar and never divides by zero', () {
    expect(progress(100000, 25000).ratio, 0.25);
    expect(progress(0, 100).ratio, 0);
  });
}