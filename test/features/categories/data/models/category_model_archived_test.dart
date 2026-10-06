import 'package:finly/features/categories/data/models/category_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const row = {
    'id': 'c1',
    'workspace_id': 'w1',
    'name': 'Alimentação',
    'kind': 'expense',
    'icon': 'restaurant',
    'color': '#F29D38',
    'is_default': true,
    'archived_at': null,
  };

  test('a category with no archive date is active', () {
    expect(CategoryModel.fromMap(row).isArchived, isFalse);
  });

  test('a category with an archive date is archived', () {
    final model = CategoryModel.fromMap({
      ...row,
      'archived_at': '2026-10-05T12:00:00+00:00',
    });

    expect(model.isArchived, isTrue);
  });

  test('a row without the archive column is read as active', () {
    final withoutColumn = {...row}..remove('archived_at');

    expect(CategoryModel.fromMap(withoutColumn).isArchived, isFalse);
  });
}