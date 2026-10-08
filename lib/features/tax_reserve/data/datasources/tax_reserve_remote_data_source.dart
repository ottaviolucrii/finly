import 'package:finly/core/utils/iso_date.dart';
import 'package:finly/features/tax_reserve/domain/entities/tax_reserve_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class TaxReserveRemoteDataSource {
  Future<TaxReserveData> getData(String workspaceId, DateTime month);

  Future<void> savePercent(String workspaceId, int percentBps);
}

class TaxReserveRemoteDataSourceImpl implements TaxReserveRemoteDataSource {
  final SupabaseClient _client;

  const TaxReserveRemoteDataSourceImpl(this._client);

  static int _sum(List<Map<String, dynamic>> rows, String column) {
    return rows.fold<int>(0, (total, row) => total + (row[column] as num).toInt());
  }

  @override
  Future<TaxReserveData> getData(String workspaceId, DateTime month) async {
    final workspace = await _client
        .from('workspaces')
        .select('tax_reserve_bps, base_currency')
        .eq('id', workspaceId)
        .single();

    final currency = workspace['base_currency'] as String;
    final percentBps = (workspace['tax_reserve_bps'] as num).toInt();
    final monthKey = isoDate(DateTime(month.year, month.month));

    // What came in: only what already happened (posted), like the report.
    final flows = await _client
        .from('monthly_flow')
        .select('income_cents')
        .eq('workspace_id', workspaceId)
        .eq('currency', currency)
        .eq('month', monthKey);

    // The categories marked as tax, and what was spent on them in the month
    // (pending included: a tax that is due is part of the month).
    final taxCategories = await _client
        .from('categories')
        .select('id')
        .eq('workspace_id', workspaceId)
        .eq('is_tax', true);

    var taxCents = 0;
    if (taxCategories.isNotEmpty) {
      final ids = taxCategories.map((row) => row['id'] as String).join(',');
      final spends = await _client
          .from('monthly_category_spend')
          .select('spent_cents')
          .eq('workspace_id', workspaceId)
          .eq('currency', currency)
          .eq('month', monthKey)
          .filter('category_id', 'in', '($ids)');
      taxCents = _sum(spends, 'spent_cents');
    }

    return TaxReserveData(
      percentBps: percentBps,
      currency: currency,
      incomeCents: _sum(flows, 'income_cents'),
      taxCents: taxCents,
    );
  }

  @override
  Future<void> savePercent(String workspaceId, int percentBps) async {
    // Row Level Security: only the owner can change the workspace, and a check
    // of the table accepts a value above zero only for a company.
    await _client
        .from('workspaces')
        .update({'tax_reserve_bps': percentBps})
        .eq('id', workspaceId);
  }
}
