import 'package:equatable/equatable.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';

class UserEntity extends Equatable {
  final String id;
  final String fullName;
  final String email;
  final List<WorkspaceEntity> workspaces;
  final String? activeWorkspaceId;

  const UserEntity({
    required this.id,
    required this.fullName,
    required this.email,
    required this.workspaces,
    this.activeWorkspaceId,
  });

  /// Currently selected workspace, or null if none is active yet
  WorkspaceEntity? get activeWorkspace {
    for (final workspace in workspaces) {
      if (workspace.id == activeWorkspaceId) return workspace;
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        fullName,
        email,
        workspaces,
        activeWorkspaceId,
      ];
}