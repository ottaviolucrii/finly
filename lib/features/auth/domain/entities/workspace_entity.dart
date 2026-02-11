
import 'package:equatable/equatable.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';

class WorkspaceEntity extends Equatable{
  final String id;
  final String name;
  final String taxId;
  final WorkspaceType type;

  const WorkspaceEntity ({
    required this.id,
    required this.name,
    required this.taxId,
    required this.type
  });

  @override
  List<Object?> get props => [id, name, taxId, type];
}