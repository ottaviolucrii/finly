import 'package:finly/features/categories/data/models/category_model.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
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
  };

  test('reads every field of a categories row', () {
    final model = CategoryModel.fromMap(row);

    expect(model.id, 'c1');
    expect(model.workspaceId, 'w1');
    expect(model.name, 'Alimentação');
    expect(model.kind, CategoryKind.expense);
    expect(model.icon, 'restaurant');
    expect(model.colorHex, '#F29D38');
    expect(model.isDefault, isTrue);
  });

  test('reads an income category', () {
    final model = CategoryModel.fromMap({...row, 'kind': 'income'});

    expect(model.kind, CategoryKind.income);
  });

  test('an unknown kind fails loudly instead of guessing', () {
    expect(
      () => CategoryModel.fromMap({...row, 'kind': 'transfer'}),
      throwsArgumentError,
    );
  });
}