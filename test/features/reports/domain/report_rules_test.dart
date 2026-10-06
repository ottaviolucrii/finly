import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/dashboard/domain/chart_rules.dart';
import 'package:finly/features/dashboard/domain/entities/category_spend_entry.dart';
import 'package:finly/features/reports/domain/report_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CategoryEntity category(String id, String name, String color) {
    return CategoryEntity(
      id: id,
      workspaceId: 'w1',
      name: name,
      kind: CategoryKind.expense,
      icon: 'category',
      colorHex: color,
      isDefault: false,
    );
  }

  CategorySpendEntry spend(String? id, int cents, {String currency = 'BRL'}) {
    return CategorySpendEntry(categoryId: id, currency: currency, spentCents: cents);
  }

  group('percentChange', () {
    test('is null when there is nothing to compare with', () {
      expect(percentChange(500, 0), isNull);
      expect(percentChange(0, 0), isNull);
    });

    test('a rise is positive and a drop is negative', () {
      expect(percentChange(150, 100), 50);
      expect(percentChange(50, 100), -50);
    });

    test('no change is zero', () {
      expect(percentChange(100, 100), 0);
    });

    test('rounds to a whole percent', () {
      expect(percentChange(101, 300), -66);
      expect(percentChange(400, 300), 33);
    });

    test('a spending that dropped to nothing is -100', () {
      expect(percentChange(0, 250), -100);
    });
  });

  group('buildCategoryChanges', () {
    final categories = [
      category('c1', 'Alimentação', '#F29D38'),
      category('c2', 'Transporte', '#1060E3'),
      category('c3', 'Moradia', '#1A2E44'),
      category('c4', 'Lazer', '#C2569B'),
      category('c5', 'Saúde', '#1E7A4F'),
    ];

    test('orders the rows from the biggest and carries the previous month', () {
      final rows = buildCategoryChanges(
        [spend('c2', 500), spend('c1', 900)],
        [spend('c1', 600), spend('c2', 800)],
        categories,
        'BRL',
      );

      expect(rows.map((r) => r.name), ['Alimentação', 'Transporte']);
      expect(rows.first.spentCents, 900);
      expect(rows.first.previousCents, 600);
      expect(rows.last.previousCents, 800);
    });

    test('a category with no spending the month before has previous 0', () {
      final rows = buildCategoryChanges([spend('c1', 900)], const [], categories, 'BRL');

      expect(rows.single.previousCents, 0);
    });

    test('a category spent only the month before does not appear', () {
      final rows = buildCategoryChanges(
        [spend('c1', 900)],
        [spend('c2', 700)],
        categories,
        'BRL',
      );

      expect(rows.map((r) => r.name), ['Alimentação']);
    });

    test('expenses with no category get the neutral row', () {
      final rows = buildCategoryChanges([spend(null, 300)], const [], categories, 'BRL');

      expect(rows.single.name, uncategorizedName);
      expect(rows.single.colorHex, neutralColorHex);
    });

    test('ignores other currencies and zero amounts', () {
      final rows = buildCategoryChanges(
        [spend('c1', 0), spend('c2', 400, currency: 'USD'), spend('c3', 70)],
        const [],
        categories,
        'BRL',
      );

      expect(rows.map((r) => r.name), ['Moradia']);
    });

    test('groups the smallest categories into "Outras" past the limit', () {
      final rows = buildCategoryChanges(
        [
          spend('c1', 500),
          spend('c2', 400),
          spend('c3', 300),
          spend('c4', 200),
          spend('c5', 100),
        ],
        [spend('c4', 50), spend('c5', 25), spend('c1', 480)],
        categories,
        'BRL',
        maxRows: 4,
      );

      expect(rows, hasLength(4));
      expect(rows.take(3).map((r) => r.name), ['Alimentação', 'Transporte', 'Moradia']);
      expect(rows.last.name, otherCategoriesName);
      expect(rows.last.isOther, isTrue);
      expect(rows.last.spentCents, 300);
      expect(rows.last.previousCents, 75);
    });

    test('keeps the total when grouping', () {
      final entries = [
        for (var i = 0; i < 5; i++) spend('c${i + 1}', (i + 1) * 100),
      ];

      final rows = buildCategoryChanges(entries, const [], categories, 'BRL', maxRows: 3);

      expect(rows.fold<int>(0, (sum, r) => sum + r.spentCents), 1500);
    });

    test('is empty when nothing was spent', () {
      expect(buildCategoryChanges(const [], const [], categories, 'BRL'), isEmpty);
    });
  });
}