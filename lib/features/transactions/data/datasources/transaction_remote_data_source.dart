import 'package:finly/features/transactions/data/models/transaction_model.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class TransactionRemoteDataSource {
  Future<List<TransactionModel>> getTransactions(
    String workspaceId, {
    required int limit,
  });

  Future<TransactionModel> createTransaction({
    required String workspaceId,
    required String accountId,
    String? categoryId,
    required TransactionType type,
    required TransactionStatus status,
    required int amountCents,
    required String currency,
    required String description,
    required DateTime occurredAt,
  });

  Future<void> updateStatus(String transactionId, TransactionStatus status);

  Future<void> setDeleted(String transactionId, {required bool deleted});
}

class TransactionRemoteDataSourceImpl implements TransactionRemoteDataSource {
  final SupabaseClient _client;

  const TransactionRemoteDataSourceImpl(this._client);

  @override
  Future<List<TransactionModel>> getTransactions(
    String workspaceId, {
    required int limit,
  }) async {
    // Row Level Security limits this to the user's own workspaces; the
    // filters pick the workspace and hide soft-deleted rows.
    final rows = await _client
        .from('transactions')
        .select()
        .eq('workspace_id', workspaceId)
        .filter('deleted_at', 'is', 'null')
        .order('occurred_at', ascending: false)
        .limit(limit);

    return rows.map(TransactionModel.fromMap).toList();
  }

  @override
  Future<TransactionModel> createTransaction({
    required String workspaceId,
    required String accountId,
    String? categoryId,
    required TransactionType type,
    required TransactionStatus status,
    required int amountCents,
    required String currency,
    required String description,
    required DateTime occurredAt,
  }) async {
    // The database checks that the account belongs to this workspace, that
    // the currency matches the account, and that the category fits the type.
    final row = await _client
        .from('transactions')
        .insert({
          'workspace_id': workspaceId,
          'account_id': accountId,
          'category_id': categoryId,
          'type': type.dbValue,
          'status': status.dbValue,
          'amount_cents': amountCents,
          'currency': currency,
          'description': description,
          'occurred_at': occurredAt.toUtc().toIso8601String(),
        })
        .select()
        .single();

    return TransactionModel.fromMap(row);
  }

  @override
  Future<void> updateStatus(
    String transactionId,
    TransactionStatus status,
  ) async {
    await _client
        .from('transactions')
        .update({'status': status.dbValue})
        .eq('id', transactionId);
  }

  @override
  Future<void> setDeleted(
    String transactionId, {
    required bool deleted,
  }) async {
    await _client
        .from('transactions')
        .update({
          'deleted_at': deleted ? DateTime.now().toUtc().toIso8601String() : null,
        })
        .eq('id', transactionId);
  }
}