import 'package:equatable/equatable.dart';
import 'package:finly/features/auth/domain/entities/tax_id_type.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';

class WorkspaceEntity extends Equatable {
  final String id;
  final String ownerId;
  final String name;
  final String taxId;
  final TaxIdType taxIdType;
  final WorkspaceType type;

  const WorkspaceEntity({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.taxId,
    required this.taxIdType,
    required this.type,
  });

  @override
  List<Object?> get props => [id, ownerId, name, taxId, taxIdType, type];
}