import 'package:finly/features/dashboard/data/models/cash_flow_entry_model.dart';
import 'package:finly/features/transactions/data/models/transaction_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class DashboardRemoteDataSource {
  Future<List<CashFlowEntryModel>> getCashFlow(
    String workspaceId,
    DateTime month,
  );

  Future<List<TransactionModel>> getUpcoming(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  });
}

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  final SupabaseClient _client;

  const DashboardRemoteDataSourceImpl(this._client);

  @override
  Future<List<CashFlowEntryModel>> getCashFlow(
    String workspaceId,
    DateTime month,
  ) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);

    // Only the four columns the totals need. Transfers are left out by the
    // type filter, and failed or deleted entries by the other two.
    final rows = await _client
        .from('transactions')
        .select('type, status, amount_cents, currency')
        .eq('workspace_id', workspaceId)
        .filter('deleted_at', 'is', 'null')
        .filter('type', 'in', '(income,expense)')
        .neq('status', 'failed')
        .gte('occurred_at', start.toUtc().toIso8601String())
        .lt('occurred_at', end.toUtc().toIso8601String());

    return rows.map(CashFlowEntryModel.fromMap).toList();
  }

  @override
  Future<List<TransactionModel>> getUpcoming(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client
        .from('transactions')
        .select()
        .eq('workspace_id', workspaceId)
        .eq('status', 'pending')
        .filter('deleted_at', 'is', 'null')
        .filter('type', 'in', '(income,expense)')
        .gte('occurred_at', from.toUtc().toIso8601String())
        .lt('occurred_at', to.toUtc().toIso8601String())
        .order('occurred_at')
        .limit(20);

    return rows.map(TransactionModel.fromMap).toList();
  }
}