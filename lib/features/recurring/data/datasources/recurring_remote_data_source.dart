import 'package:finly/features/budgets/domain/budget_rules.dart';
import 'package:finly/features/recurring/data/models/recurring_model.dart';
import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class RecurringRemoteDataSource {
  Future<List<RecurringModel>> getRecurring(String workspaceId);

  Future<RecurringModel> createRecurring({
    required String workspaceId,
    required String accountId,
    String? categoryId,
    required TransactionType type,
    required int amountCents,
    required String currency,
    required String description,
    required RecurrenceFrequency frequency,
    required int intervalCount,
    required DateTime startDate,
    DateTime? endDate,
  });

  Future<void> updateRecurring({
    required String id,
    String? categoryId,
    required int amountCents,
    required String description,
    DateTime? endDate,
  });

  Future<void> deleteRecurring(String id);

  Future<void> setActive(String id, {required bool active});

  Future<int> generateDue();
}

class RecurringRemoteDataSourceImpl implements RecurringRemoteDataSource {
  final SupabaseClient _client;

  const RecurringRemoteDataSourceImpl(this._client);

  @override
  Future<List<RecurringModel>> getRecurring(String workspaceId) async {
    final rows = await _client
        .from('recurring_transactions')
        .select()
        .eq('workspace_id', workspaceId)
        .order('created_at');

    return rows.map(RecurringModel.fromMap).toList();
  }

  @override
  Future<RecurringModel> createRecurring({
    required String workspaceId,
    required String accountId,
    String? categoryId,
    required TransactionType type,
    required int amountCents,
    required String currency,
    required String description,
    required RecurrenceFrequency frequency,
    required int intervalCount,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    // The database checks that the account belongs to this workspace, that
    // the currency matches the account, and the ranges of every field.
    final row = await _client
        .from('recurring_transactions')
        .insert({
          'workspace_id': workspaceId,
          'account_id': accountId,
          'category_id': categoryId,
          'type': type.dbValue,
          'amount_cents': amountCents,
          'currency': currency,
          'description': description,
          'frequency': frequency.dbValue,
          'interval_count': intervalCount,
          'start_date': isoDate(startDate),
          'end_date': endDate == null ? null : isoDate(endDate),
        })
        .select()
        .single();

    return RecurringModel.fromMap(row);
  }

  @override
  Future<void> updateRecurring({
    required String id,
    String? categoryId,
    required int amountCents,
    required String description,
    DateTime? endDate,
  }) async {
    // Database function (sql/12_recurring_edit_delete.sql): changes the item
    // and, in the same operation, its pending occurrences.
    await _client.rpc(
      'update_recurring',
      params: {
        'p_recurring_id': id,
        'p_description': description,
        'p_amount_cents': amountCents,
        'p_category_id': categoryId,
        'p_end_date': endDate == null ? null : isoDate(endDate),
      },
    );
  }

  @override
  Future<void> deleteRecurring(String id) async {
    // Database function: removes the pending occurrences and detaches the
    // history, because the table's foreign key would not let the item go.
    await _client.rpc('delete_recurring', params: {'p_recurring_id': id});
  }

  @override
  Future<void> setActive(String id, {required bool active}) async {
    await _client
        .from('recurring_transactions')
        .update({'is_active': active})
        .eq('id', id);
  }

  @override
  Future<int> generateDue() async {
    // Database function (sql/03_logic.sql): creates the pending transactions
    // of every active item of the user, up to 35 days ahead. Running it again
    // never duplicates anything.
    final created = await _client.rpc('generate_my_recurring');
    return (created as num).toInt();
  }
}