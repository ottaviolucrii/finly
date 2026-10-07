import 'package:finly/core/utils/iso_date.dart';
import 'package:finly/features/budgets/data/models/budget_model.dart';
import 'package:finly/features/budgets/data/models/category_spend_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class BudgetRemoteDataSource {
  Future<List<BudgetModel>> getBudgets(String workspaceId);

  Future<List<CategorySpendModel>> getMonthlySpend(
    String workspaceId,
    DateTime month,
  );

  Future<BudgetModel> saveBudget({
    required String workspaceId,
    required String categoryId,
    required DateTime effectiveFrom,
    required int limitCents,
    required String currency,
  });

  Future<void> deleteBudget(String budgetId);
}

class BudgetRemoteDataSourceImpl implements BudgetRemoteDataSource {
  final SupabaseClient _client;

  const BudgetRemoteDataSourceImpl(this._client);

  @override
  Future<List<BudgetModel>> getBudgets(String workspaceId) async {
    final rows = await _client
        .from('budgets')
        .select()
        .eq('workspace_id', workspaceId)
        .order('effective_from');

    return rows.map(BudgetModel.fromMap).toList();
  }

  @override
  Future<List<CategorySpendModel>> getMonthlySpend(
    String workspaceId,
    DateTime month,
  ) async {
    // View sql/03_logic.sql: expenses per category and currency, by month in
    // America/Sao_Paulo; failed and deleted ones and transfers are excluded.
    final rows = await _client
        .from('monthly_category_spend')
        .select()
        .eq('workspace_id', workspaceId)
        .eq('month', isoDate(month));

    return rows.map(CategorySpendModel.fromMap).toList();
  }

  @override
  Future<BudgetModel> saveBudget({
    required String workspaceId,
    required String categoryId,
    required DateTime effectiveFrom,
    required int limitCents,
    required String currency,
  }) async {
    // One row per workspace, category and starting month: saving again
    // replaces that version instead of failing.
    final row = await _client
        .from('budgets')
        .upsert(
          {
            'workspace_id': workspaceId,
            'category_id': categoryId,
            'effective_from': isoDate(effectiveFrom),
            'limit_cents': limitCents,
            'currency': currency,
          },
          onConflict: 'workspace_id,category_id,effective_from',
        )
        .select()
        .single();

    return BudgetModel.fromMap(row);
  }

  @override
  Future<void> deleteBudget(String budgetId) async {
    await _client.from('budgets').delete().eq('id', budgetId);
  }
}