import 'package:finly/features/accounts/data/models/account_model.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class AccountRemoteDataSource {
  Future<List<AccountModel>> getAccounts(String workspaceId);

  Future<List<AccountModel>> getArchivedAccounts(String workspaceId);

  Future<AccountModel> createAccount({
    required String workspaceId,
    required String name,
    required AccountType type,
    required String currency,
    required int openingBalanceCents,
  });

  Future<AccountModel> updateAccount({
    required String accountId,
    required String name,
    int? openingBalanceCents,
  });

  Future<void> archiveAccount(String accountId);

  Future<void> restoreAccount(String accountId);
}

class AccountRemoteDataSourceImpl implements AccountRemoteDataSource {
  final SupabaseClient _client;

  const AccountRemoteDataSourceImpl(this._client);

  @override
  Future<List<AccountModel>> getAccounts(String workspaceId) async {
    // Row Level Security already limits this to the user's own workspaces;
    // the filters pick the active workspace and hide archived accounts.
    final accounts = await _client
        .from('accounts')
        .select()
        .eq('workspace_id', workspaceId)
        .filter('archived_at', 'is', 'null')
        .order('created_at');

    return _withBalances(workspaceId, accounts);
  }

  @override
  Future<List<AccountModel>> getArchivedAccounts(String workspaceId) async {
    final accounts = await _client
        .from('accounts')
        .select()
        .eq('workspace_id', workspaceId)
        .not('archived_at', 'is', null)
        .order('archived_at', ascending: false);

    return _withBalances(workspaceId, accounts);
  }

  /// Balances are derived by the database view, never stored.
  Future<List<AccountModel>> _withBalances(
    String workspaceId,
    List<Map<String, dynamic>> accounts,
  ) async {
    final balances = await _client
        .from('account_balances')
        .select()
        .eq('workspace_id', workspaceId);

    final balanceById = {
      for (final row in balances) row['account_id'] as String: row,
    };

    return accounts
        .map(
          (row) => AccountModel.fromMaps(
            account: row,
            balance: balanceById[row['id'] as String],
          ),
        )
        .toList();
  }

  @override
  Future<AccountModel> createAccount({
    required String workspaceId,
    required String name,
    required AccountType type,
    required String currency,
    required int openingBalanceCents,
  }) async {
    final row = await _client
        .from('accounts')
        .insert({
          'workspace_id': workspaceId,
          'name': name,
          'type': type.dbValue,
          'currency': currency,
          'opening_balance_cents': openingBalanceCents,
        })
        .select()
        .single();

    return AccountModel.fromMaps(account: row);
  }

  @override
  Future<AccountModel> updateAccount({
    required String accountId,
    required String name,
    int? openingBalanceCents,
  }) async {
    // Two active accounts cannot share a name (a unique index in the
    // database), and the type and the currency are not touched.
    final values = <String, dynamic>{'name': name};
    if (openingBalanceCents != null) {
      values['opening_balance_cents'] = openingBalanceCents;
    }

    final row = await _client
        .from('accounts')
        .update(values)
        .eq('id', accountId)
        .select()
        .single();

    return AccountModel.fromMaps(account: row);
  }

  @override
  Future<void> archiveAccount(String accountId) async {
    await _client
        .from('accounts')
        .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', accountId);
  }

  @override
  Future<void> restoreAccount(String accountId) async {
    // The unique name index only covers active accounts, so this fails when
    // another active account took the name in the meantime.
    await _client
        .from('accounts')
        .update({'archived_at': null})
        .eq('id', accountId);
  }
}