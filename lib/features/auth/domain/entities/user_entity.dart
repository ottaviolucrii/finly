
import 'package:equatable/equatable.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';

class UserEntity extends Equatable{

  final String id;
  final String email;
  final List<WorkspaceEntity> workspaces;
  final String activeWorkspaceId;

  const UserEntity ({
    required this.id,
    required this.email,
    required this.workspaces,
    required this.activeWorkspaceId
  });

  /// Helper to quickly get the current selected workspace details
  WorkspaceEntity get activeWorkspace => workspaces.firstWhere(
    (workspace) => workspace.id == activeWorkspaceId,
  );

  @override
  List<Object?> get props => [id, email, workspaces, activeWorkspaceId];
} 