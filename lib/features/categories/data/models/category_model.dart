import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';

class CategoryModel extends CategoryEntity {
  const CategoryModel({
    required super.id,
    required super.workspaceId,
    required super.name,
    required super.kind,
    required super.icon,
    required super.colorHex,
    required super.isDefault,
  });

  /// [map] is a row of the `categories` table.
  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      workspaceId: map['workspace_id'] as String,
      name: map['name'] as String,
      kind: CategoryKind.fromDb(map['kind'] as String),
      icon: map['icon'] as String,
      colorHex: map['color'] as String,
      isDefault: map['is_default'] as bool,
    );
  }
}