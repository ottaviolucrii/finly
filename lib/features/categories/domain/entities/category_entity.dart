import 'package:equatable/equatable.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';

class CategoryEntity extends Equatable {
  final String id;
  final String workspaceId;
  final String name;
  final CategoryKind kind;

  /// A Material icon name such as "restaurant" (mapped in the UI).
  final String icon;

  /// A hex colour such as "#F29D38".
  final String colorHex;
  final bool isDefault;

  const CategoryEntity({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.kind,
    required this.icon,
    required this.colorHex,
    required this.isDefault,
  });

  @override
  List<Object?> get props =>
      [id, workspaceId, name, kind, icon, colorHex, isDefault];
}