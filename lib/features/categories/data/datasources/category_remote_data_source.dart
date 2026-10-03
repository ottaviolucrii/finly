import 'package:finly/features/categories/data/models/category_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class CategoryRemoteDataSource {
  Future<List<CategoryModel>> getCategories(String workspaceId);
}

class CategoryRemoteDataSourceImpl implements CategoryRemoteDataSource {
  final SupabaseClient _client;

  const CategoryRemoteDataSourceImpl(this._client);

  @override
  Future<List<CategoryModel>> getCategories(String workspaceId) async {
    final rows = await _client
        .from('categories')
        .select()
        .eq('workspace_id', workspaceId)
        .filter('archived_at', 'is', 'null')
        .order('name');

    return rows.map(CategoryModel.fromMap).toList();
  }
}