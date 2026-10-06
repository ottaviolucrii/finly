import 'package:finly/features/dashboard/data/models/category_spend_entry_model.dart';
import 'package:finly/features/dashboard/data/models/monthly_flow_entry_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MonthlyFlowEntryModel', () {
    test('reads a row of the monthly_flow view', () {
      final model = MonthlyFlowEntryModel.fromMap({
        'workspace_id': 'w1',
        'currency': 'BRL',
        'month': '2026-10-01',
        'income_cents': 200000,
        'expense_cents': 460001,
      });

      expect(model.month, DateTime(2026, 10));
      expect(model.currency, 'BRL');
      expect(model.incomeCents, 200000);
      expect(model.expenseCents, 460001);
    });

    test('reads amounts that arrive as doubles', () {
      final model = MonthlyFlowEntryModel.fromMap({
        'currency': 'USD',
        'month': '2026-09-01',
        'income_cents': 0.0,
        'expense_cents': 5000.0,
      });

      expect(model.expenseCents, 5000);
    });
  });

  group('CategorySpendEntryModel', () {
    test('reads a row with a category', () {
      final model = CategorySpendEntryModel.fromMap({
        'category_id': 'c1',
        'currency': 'BRL',
        'spent_cents': 9000,
      });

      expect(model.categoryId, 'c1');
      expect(model.spentCents, 9000);
    });

    test('reads a row with no category', () {
      final model = CategorySpendEntryModel.fromMap({
        'category_id': null,
        'currency': 'BRL',
        'spent_cents': 1500,
      });

      expect(model.categoryId, isNull);
    });
  });
}