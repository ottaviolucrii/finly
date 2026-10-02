import 'package:finly/features/auth/data/models/workspace_model.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.fullName,
    required super.email,
    required super.workspaces,
    super.activeWorkspaceId,
  });

  /// [profile] is a row of `profiles`. The e-mail comes from the auth user,
  /// since it is not stored in `profiles`.
  factory UserModel.fromMap({
    required Map<String, dynamic> profile,
    required String email,
    required List<Map<String, dynamic>> workspaces,
  }) {
    return UserModel(
      id: profile['id'] as String,
      fullName: profile['full_name'] as String,
      email: email,
      activeWorkspaceId: profile['active_workspace_id'] as String?,
      workspaces: workspaces.map(WorkspaceModel.fromMap).toList(),
    );
  }
}