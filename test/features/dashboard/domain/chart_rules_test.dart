import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/dashboard/domain/chart_rules.dart';
import 'package:finly/features/dashboard/domain/entities/category_spend_entry.dart';
import 'package:finly/features/dashboard/domain/entities/monthly_flow_entry.dart';
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

  group('lastMonths', () {
    test('lists six month starts, oldest first, ending in the current month', () {
      expect(lastMonths(DateTime(2026, 10, 6)), [
        DateTime(2026, 5),
        DateTime(2026, 6),
        DateTime(2026, 7),
        DateTime(2026, 8),
        DateTime(2026, 9),
        DateTime(2026, 10),
      ]);
    });

    test('crosses the year', () {
      final months = lastMonths(DateTime(2026, 2, 10));

      expect(months.first, DateTime(2025, 9));
      expect(months.last, DateTime(2026, 2));
    });

    test('honours the count', () {
      expect(lastMonths(DateTime(2026, 10, 6), count: 1), [DateTime(2026, 10)]);
    });
  });

  group('buildMonthlyPoints', () {
    final months = lastMonths(DateTime(2026, 10, 6));

    test('fills the months with no entries with zeros', () {
      final points = buildMonthlyPoints(const [], months, 'BRL');

      expect(points, hasLength(6));
      expect(points.every((p) => p.isEmpty), isTrue);
      expect(points.first.month, DateTime(2026, 5));
    });

    test('places each entry in its month', () {
      final points = buildMonthlyPoints(
        [
          MonthlyFlowEntry(
            month: DateTime(2026, 10),
            currency: 'BRL',
            incomeCents: 200000,
            expenseCents: 460001,
          ),
          MonthlyFlowEntry(
            month: DateTime(2026, 8),
            currency: 'BRL',
            incomeCents: 10000,
            expenseCents: 0,
          ),
        ],
        months,
        'BRL',
      );

      expect(points.last.incomeCents, 200000);
      expect(points.last.expenseCents, 460001);
      expect(points[3].month, DateTime(2026, 8));
      expect(points[3].incomeCents, 10000);
      expect(points[4].isEmpty, isTrue);
    });

    test('ignores other currencies and months outside the window', () {
      final points = buildMonthlyPoints(
        [
          MonthlyFlowEntry(
            month: DateTime(2026, 10),
            currency: 'USD',
            incomeCents: 999,
            expenseCents: 999,
          ),
          MonthlyFlowEntry(
            month: DateTime(2025, 1),
            currency: 'BRL',
            incomeCents: 999,
            expenseCents: 999,
          ),
        ],
        months,
        'BRL',
      );

      expect(points.every((p) => p.isEmpty), isTrue);
    });

    test('adds up entries that fall in the same month', () {
      final points = buildMonthlyPoints(
        [
          MonthlyFlowEntry(
            month: DateTime(2026, 10),
            currency: 'BRL',
            incomeCents: 100,
            expenseCents: 50,
          ),
          MonthlyFlowEntry(
            month: DateTime(2026, 10),
            currency: 'BRL',
            incomeCents: 200,
            expenseCents: 25,
          ),
        ],
        months,
        'BRL',
      );

      expect(points.last.incomeCents, 300);
      expect(points.last.expenseCents, 75);
    });
  });

  group('buildCategorySlices', () {
    final categories = [
      category('c1', 'Alimentação', '#F29D38'),
      category('c2', 'Transporte', '#1060E3'),
      category('c3', 'Moradia', '#1A2E44'),
      category('c4', 'Lazer', '#C2569B'),
      category('c5', 'Saúde', '#1E7A4F'),
      category('c6', 'Educação', '#6B5BD2'),
    ];

    test('orders the slices from the biggest to the smallest', () {
      final slices = buildCategorySlices(
        [spend('c2', 500), spend('c1', 900), spend('c3', 100)],
        categories,
        'BRL',
      );

      expect(slices.map((s) => s.name), ['Alimentação', 'Transporte', 'Moradia']);
      expect(slices.first.colorHex, '#F29D38');
      expect(slices.first.spentCents, 900);
    });

    test('puts expenses with no category in a neutral slice', () {
      final slices = buildCategorySlices([spend(null, 300)], categories, 'BRL');

      expect(slices.single.name, uncategorizedName);
      expect(slices.single.colorHex, neutralColorHex);
    });

    test('treats an unknown category id as no category', () {
      final slices = buildCategorySlices([spend('zzz', 300)], categories, 'BRL');

      expect(slices.single.name, uncategorizedName);
    });

    test('merges entries of the same category', () {
      final slices = buildCategorySlices(
        [spend('c1', 100), spend('c1', 250)],
        categories,
        'BRL',
      );

      expect(slices.single.spentCents, 350);
    });

    test('ignores zero amounts and other currencies', () {
      final slices = buildCategorySlices(
        [spend('c1', 0), spend('c2', 400, currency: 'USD'), spend('c3', 70)],
        categories,
        'BRL',
      );

      expect(slices.map((s) => s.name), ['Moradia']);
    });

    test('keeps five categories as they are', () {
      final slices = buildCategorySlices(
        [
          spend('c1', 500),
          spend('c2', 400),
          spend('c3', 300),
          spend('c4', 200),
          spend('c5', 100),
        ],
        categories,
        'BRL',
      );

      expect(slices, hasLength(5));
      expect(slices.any((s) => s.isOther), isFalse);
    });

    test('groups the smallest categories into "Outras" past five', () {
      final slices = buildCategorySlices(
        [
          spend('c1', 600),
          spend('c2', 500),
          spend('c3', 400),
          spend('c4', 300),
          spend('c5', 200),
          spend('c6', 100),
        ],
        categories,
        'BRL',
      );

      expect(slices, hasLength(5));
      expect(slices.take(4).map((s) => s.name), [
        'Alimentação',
        'Transporte',
        'Moradia',
        'Lazer',
      ]);
      expect(slices.last.name, otherCategoriesName);
      expect(slices.last.isOther, isTrue);
      expect(slices.last.spentCents, 300);
    });

    test('keeps the total when grouping', () {
      final entries = [
        for (var i = 0; i < 6; i++) spend('c${i + 1}', (i + 1) * 100),
      ];

      final slices = buildCategorySlices(entries, categories, 'BRL');

      expect(slices.fold<int>(0, (sum, s) => sum + s.spentCents), 2100);
    });

    test('is empty when nothing was spent', () {
      expect(buildCategorySlices(const [], categories, 'BRL'), isEmpty);
    });
  });
}