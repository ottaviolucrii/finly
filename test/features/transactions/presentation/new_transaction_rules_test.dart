import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/transactions/presentation/new_transaction_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 11, 15, 30);

  test('isFutureDay compares days, not times', () {
    expect(isFutureDay(DateTime(2026, 10, 12), now), isTrue);
    expect(isFutureDay(DateTime(2026, 10, 11, 23, 59), now), isFalse);
    expect(isFutureDay(DateTime(2026, 10, 10), now), isFalse);
  });

  test('today keeps the time; another day is recorded at noon', () {
    expect(occurredAtFor(DateTime(2026, 10, 11), now), now);
    expect(occurredAtFor(DateTime(2026, 10, 10), now), DateTime(2026, 10, 10, 12));
    expect(occurredAtFor(DateTime(2026, 10, 20, 8), now), DateTime(2026, 10, 20, 12));
  });

  test('dayFor: today, yesterday and a picked day', () {
    final picked = DateTime(2026, 9, 3, 10);
    expect(dayFor(QuickDay.today, now, picked), DateTime(2026, 10, 11));
    expect(dayFor(QuickDay.yesterday, now, picked), DateTime(2026, 10, 10));
    expect(dayFor(QuickDay.other, now, picked), DateTime(2026, 9, 3));
  });

  test('yesterday works on the first day of a month and of a year', () {
    expect(dayFor(QuickDay.yesterday, DateTime(2026, 11, 1, 9), now), DateTime(2026, 10, 31));
    expect(dayFor(QuickDay.yesterday, DateTime(2027, 1, 1, 9), now), DateTime(2026, 12, 31));
  });

  group('descriptionFor', () {
    const market = CategoryEntity(
      id: 'c1',
      workspaceId: 'w1',
      name: 'Mercado',
      kind: CategoryKind.expense,
      icon: 'shopping_cart',
      colorHex: '#F29D38',
      isDefault: true,
    );

    test('what was typed, without spaces around it', () {
      expect(descriptionFor('  Padaria  ', market), 'Padaria');
    });

    test('the category name when nothing was typed', () {
      expect(descriptionFor('   ', market), 'Mercado');
    });

    test('nothing when there is neither', () {
      expect(descriptionFor('', null), isNull);
    });
  });
}
