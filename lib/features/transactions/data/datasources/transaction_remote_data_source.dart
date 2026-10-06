import 'package:finly/features/transactions/data/like_pattern.dart';
import 'package:finly/features/transactions/data/models/transaction_model.dart';
import 'package:finly/features/transactions/domain/entities/transaction_filter.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class TransactionRemoteDataSource {
  Future<List<TransactionModel>> getTransactions(
    String workspaceId, {
    required int limit,
    required int offset,
    required TransactionFilter filter,
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

  Future<TransactionModel> updateTransaction({
    required String transactionId,
    String? categoryId,
    required int amountCents,
    required String description,
    required DateTime occurredAt,
    required TransactionStatus status,
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
    required int offset,
    required TransactionFilter filter,
  }) async {
    // Row Level Security limits this to the user's own workspaces; the
    // filters pick the workspace and hide soft-deleted rows.
    var query = _client
        .from('transactions')
        .select()
        .eq('workspace_id', workspaceId)
        .filter('deleted_at', 'is', 'null');

    final search = filter.search.trim();
    if (search.isNotEmpty) {
      query = query.ilike('description', '%${escapeLikePattern(search)}%');
    }
    final type = filter.type;
    if (type != null) query = query.eq('type', type.dbValue);
    final status = filter.status;
    if (status != null) query = query.eq('status', status.dbValue);
    final accountId = filter.accountId;
    if (accountId != null) query = query.eq('account_id', accountId);
    final categoryId = filter.categoryId;
    if (categoryId != null) query = query.eq('category_id', categoryId);

    // The id breaks ties, so a row never repeats or goes missing between
    // two pages.
    final rows = await query
        .order('occurred_at', ascending: false)
        .order('id')
        .range(offset, offset + limit - 1);

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
  Future<TransactionModel> updateTransaction({
    required String transactionId,
    String? categoryId,
    required int amountCents,
    required String description,
    required DateTime occurredAt,
    required TransactionStatus status,
  }) async {
    // The database refuses changes to the type, account and currency, to
    // transfers, and to the amount, status or date of a purchase on an
    // invoice that is already paid. A card purchase moved to another date
    // goes to the right invoice by itself.
    final row = await _client
        .from('transactions')
        .update({
          'category_id': categoryId,
          'amount_cents': amountCents,
          'description': description,
          'occurred_at': occurredAt.toUtc().toIso8601String(),
          'status': status.dbValue,
        })
        .eq('id', transactionId)
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