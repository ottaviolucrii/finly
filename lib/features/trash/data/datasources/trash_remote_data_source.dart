import 'package:finly/features/trash/data/models/trashed_transaction_model.dart';
import 'package:finly/features/trash/data/models/trashed_transfer_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class TrashRemoteDataSource {
  Future<List<TrashedTransactionModel>> getTrash(
    String workspaceId, {
    required int limit,
  });

  Future<List<TrashedTransferModel>> getTrashedTransfers(
    String workspaceId, {
    required int limit,
  });

  Future<void> restoreTransfer(String transferId);
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
    // are listed by getTrashedTransfers.
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

  @override
  Future<List<TrashedTransferModel>> getTrashedTransfers(
    String workspaceId, {
    required int limit,
  }) async {
    // Two legs per transfer, so twice the rows; they are grouped by transfer.
    final rows = await _client
        .from('transactions')
        .select()
        .eq('workspace_id', workspaceId)
        .not('deleted_at', 'is', null)
        .not('transfer_id', 'is', null)
        .order('deleted_at', ascending: false)
        .limit(limit * 2);

    return TrashedTransferModel.fromRows(rows).take(limit).toList();
  }

  @override
  Future<void> restoreTransfer(String transferId) async {
    // Database function (sql/14_restore_transfer.sql): brings both legs back,
    // and refuses a card invoice payment.
    await _client.rpc(
      'restore_transfer',
      params: {'p_transfer_id': transferId},
    );
  }
}