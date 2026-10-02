import 'package:finly/features/auth/domain/entities/tax_id_type.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';

class WorkspaceModel extends WorkspaceEntity {
  const WorkspaceModel({
    required super.id,
    required super.ownerId,
    required super.name,
    required super.taxId,
    required super.taxIdType,
    required super.type,
  });

  /// Builds a model from a row of the `workspaces` table.
  /// `byName` throws on an unknown value instead of silently guessing.
  factory WorkspaceModel.fromMap(Map<String, dynamic> map) {
    return WorkspaceModel(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      name: map['name'] as String,
      taxId: map['tax_id'] as String,
      taxIdType: TaxIdType.values.byName(map['tax_id_type'] as String),
      type: WorkspaceType.values.byName(map['type'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'tax_id': taxId,
      'tax_id_type': taxIdType.name,
      'type': type.name,
    };
  }
}