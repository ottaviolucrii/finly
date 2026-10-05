import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/budgets/presentation/budget_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('says nothing when all is fine and warns in words otherwise', () {
    expect(budgetLevelLabel(BudgetLevel.normal), isNull);
    expect(budgetLevelLabel(BudgetLevel.warning), 'Perto do limite');
    expect(budgetLevelLabel(BudgetLevel.over), 'Acima do orçamento');
  });
}