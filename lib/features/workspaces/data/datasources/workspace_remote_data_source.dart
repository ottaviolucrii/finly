import 'package:finly/features/auth/data/models/workspace_model.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class WorkspaceRemoteDataSource {
  Future<WorkspaceModel> createWorkspace({
    required String name,
    required WorkspaceType type,
    required String taxId,
  });
}

class WorkspaceRemoteDataSourceImpl implements WorkspaceRemoteDataSource {
  final SupabaseClient _client;

  const WorkspaceRemoteDataSourceImpl(this._client);

  @override
  Future<WorkspaceModel> createWorkspace({
    required String name,
    required WorkspaceType type,
    required String taxId,
  }) async {
    // Database function (sql/03_logic.sql): validates, seeds default
    // categories and activates the workspace if it is the first one.
    final data = await _client.rpc(
      'create_workspace',
      params: {'p_name': name, 'p_type': type.name, 'p_tax_id': taxId},
    );
    final row = data is List ? data.first : data;
    return WorkspaceModel.fromMap(Map<String, dynamic>.from(row as Map));
  }
}