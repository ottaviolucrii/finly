import 'package:finly/features/trash/data/models/trashed_transaction_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class TrashRemoteDataSource {
  Future<List<TrashedTransactionModel>> getTrash(
    String workspaceId, {
    required int limit,
  });
}

class TrashRemoteDataSourceImpl implements TrashRemoteDataSource {
  final SupabaseClient _client;

  const TrashRemoteDataSourceImpl(this._client);

  @override
  Future<List<TrashedTransactionModel>> getTrash(
    String workspaceId, {
    required int limit,
  }) async {
    // Row Level Security lets the owner read deleted rows too. Transfer legs
    // are left out: restoring one leg alone is not allowed.
    final rows = await _client
        .from('transactions')
        .select()
        .eq('workspace_id', workspaceId)
        .not('deleted_at', 'is', null)
        .filter('transfer_id', 'is', 'null')
        .order('deleted_at', ascending: false)
        .limit(limit);

    return rows.map(TrashedTransactionModel.fromMap).toList();
  }
}