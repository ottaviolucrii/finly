import 'package:finly/features/categories/data/models/category_model.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class CategoryRemoteDataSource {
  Future<List<CategoryModel>> getCategories(String workspaceId);

  Future<List<CategoryModel>> getAllCategories(String workspaceId);

  Future<CategoryModel> createCategory({
    required String workspaceId,
    required String name,
    required CategoryKind kind,
    required String icon,
    required String colorHex,
  });

  Future<CategoryModel> updateCategory({
    required String categoryId,
    required String name,
    required String icon,
    required String colorHex,
  });

  Future<void> setArchived(String categoryId, {required bool archived});
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

  @override
  Future<List<CategoryModel>> getAllCategories(String workspaceId) async {
    final rows = await _client
        .from('categories')
        .select()
        .eq('workspace_id', workspaceId)
        .order('name');

    return rows.map(CategoryModel.fromMap).toList();
  }

  @override
  Future<CategoryModel> createCategory({
    required String workspaceId,
    required String name,
    required CategoryKind kind,
    required String icon,
    required String colorHex,
  }) async {
    // Names are unique per kind, ignoring case, archived ones included.
    final row = await _client
        .from('categories')
        .insert({
          'workspace_id': workspaceId,
          'name': name,
          'kind': kind.dbValue,
          'icon': icon,
          'color': colorHex,
        })
        .select()
        .single();

    return CategoryModel.fromMap(row);
  }

  @override
  Future<CategoryModel> updateCategory({
    required String categoryId,
    required String name,
    required String icon,
    required String colorHex,
  }) async {
    final row = await _client
        .from('categories')
        .update({'name': name, 'icon': icon, 'color': colorHex})
        .eq('id', categoryId)
        .select()
        .single();

    return CategoryModel.fromMap(row);
  }

  @override
  Future<void> setArchived(String categoryId, {required bool archived}) async {
    await _client
        .from('categories')
        .update({
          'archived_at': archived ? DateTime.now().toUtc().toIso8601String() : null,
        })
        .eq('id', categoryId);
  }
}