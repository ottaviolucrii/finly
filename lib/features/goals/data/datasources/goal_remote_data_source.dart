import 'package:finly/core/utils/iso_date.dart';
import 'package:finly/features/goals/domain/entities/goal.dart';
import 'package:finly/features/goals/domain/entities/goals_snapshot.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One row of `goals` as a [Goal]. Throws when a column is not what it should
/// be, so the repository can turn it into a failure.
Goal goalFromRow(Map<String, dynamic> row) {
  final date = row['target_date'];

  return Goal(
    id: row['id'] as String,
    workspaceId: row['workspace_id'] as String,
    accountId: row['account_id'] as String,
    currency: row['currency'] as String,
    name: row['name'] as String,
    targetCents: (row['target_cents'] as num).toInt(),
    targetDate: date == null ? null : parseIsoDate(date as String),
  );
}

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class GoalRemoteDataSource {
  Future<GoalsSnapshot> getSnapshot(String workspaceId);

  Future<void> createGoal({
    required String workspaceId,
    required String accountId,
    required String currency,
    required String name,
    required int targetCents,
    DateTime? targetDate,
  });

  Future<void> updateGoal({
    required String id,
    required String accountId,
    required String name,
    required int targetCents,
    DateTime? targetDate,
  });

  Future<void> archiveGoal(String id);
}

class GoalRemoteDataSourceImpl implements GoalRemoteDataSource {
  final SupabaseClient _client;

  const GoalRemoteDataSourceImpl(this._client);

  @override
  Future<GoalsSnapshot> getSnapshot(String workspaceId) async {
    // Row Level Security: only the goals of this user's workspaces come back.
    final goals = await _client
        .from('goals')
        .select()
        .eq('workspace_id', workspaceId)
        .filter('archived_at', 'is', 'null')
        .order('created_at');

    final balances = await _client
        .from('account_balances')
        .select('account_id, posted_balance_cents')
        .eq('workspace_id', workspaceId);

    final accounts = await _client
        .from('accounts')
        .select('id, name')
        .eq('workspace_id', workspaceId);

    return GoalsSnapshot(
      goals: [for (final row in goals) goalFromRow(row)],
      balances: {
        for (final row in balances)
          row['account_id'] as String: (row['posted_balance_cents'] as num).toInt(),
      },
      accountNames: {
        for (final row in accounts) row['id'] as String: row['name'] as String,
      },
    );
  }

  @override
  Future<void> createGoal({
    required String workspaceId,
    required String accountId,
    required String currency,
    required String name,
    required int targetCents,
    DateTime? targetDate,
  }) async {
    await _client.from('goals').insert({
      'workspace_id': workspaceId,
      'account_id': accountId,
      'currency': currency,
      'name': name,
      'target_cents': targetCents,
      'target_date': targetDate == null ? null : isoDate(targetDate),
    });
  }

  @override
  Future<void> updateGoal({
    required String id,
    required String accountId,
    required String name,
    required int targetCents,
    DateTime? targetDate,
  }) async {
    // The date is always sent: null removes it. The workspace and the currency
    // of a goal never change (the database refuses it).
    await _client.from('goals').update({
      'account_id': accountId,
      'name': name,
      'target_cents': targetCents,
      'target_date': targetDate == null ? null : isoDate(targetDate),
    }).eq('id', id);
  }

  @override
  Future<void> archiveGoal(String id) async {
    await _client
        .from('goals')
        .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}
