import 'package:equatable/equatable.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';

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
  /// (e.g. a brand-new user before onboarding finishes).
  WorkspaceEntity? get activeWorkspace {
    for (final workspace in workspaces) {
      if (workspace.id == activeWorkspaceId) return workspace;
    }
    return null;
  }

  /// The workspace type the user can still add (at most one Personal and one
  /// Business). Null when the user has none yet (onboarding handles that) or
  /// already has both.
  WorkspaceType? get missingWorkspaceType {
    final types = workspaces.map((workspace) => workspace.type).toSet();
    if (types.length != 1) return null;
    return types.contains(WorkspaceType.personal)
        ? WorkspaceType.business
        : WorkspaceType.personal;
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