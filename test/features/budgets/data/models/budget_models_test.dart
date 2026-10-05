import 'package:finly/features/budgets/data/models/budget_model.dart';
import 'package:finly/features/budgets/data/models/category_spend_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BudgetModel', () {
    const row = {
      'id': 'b1',
      'workspace_id': 'w1',
      'category_id': 'c1',
      'effective_from': '2026-03-01',
      'limit_cents': 80000,
      'currency': 'BRL',
    };

    test('reads every field of a budgets row', () {
      final model = BudgetModel.fromMap(row);

      expect(model.id, 'b1');
      expect(model.workspaceId, 'w1');
      expect(model.categoryId, 'c1');
      expect(model.effectiveFrom, DateTime(2026, 3));
      expect(model.limitCents, 80000);
      expect(model.currency, 'BRL');
      expect(model.limit.format(), r'R$ 800,00');
    });

    test('reads numbers that arrive as doubles', () {
      final model = BudgetModel.fromMap({...row, 'limit_cents': 80000.0});

      expect(model.limitCents, 80000);
    });
  });

  group('CategorySpendModel', () {
    test('reads a row of the monthly spend view', () {
      final model = CategorySpendModel.fromMap(const {
        'category_id': 'c1',
        'currency': 'BRL',
        'spent_cents': 25000,
      });

      expect(model.categoryId, 'c1');
      expect(model.currency, 'BRL');
      expect(model.spentCents, 25000);
    });

    test('accepts expenses that have no category', () {
      final model = CategorySpendModel.fromMap(const {
        'category_id': null,
        'currency': 'BRL',
        'spent_cents': 100,
      });

      expect(model.categoryId, isNull);
    });
  });
}