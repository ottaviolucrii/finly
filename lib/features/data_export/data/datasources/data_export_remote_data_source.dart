import 'package:finly/features/data_export/domain/entities/user_data_snapshot.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class DataExportRemoteDataSource {
  Future<UserDataSnapshot> readAll();
}

class DataExportRemoteDataSourceImpl implements DataExportRemoteDataSource {
  /// The API returns at most this many rows per request.
  static const pageSize = 1000;

  /// A safety limit for one table, so a huge history cannot fill the phone's
  /// memory.
  static const maxRowsPerTable = 100000;

  final SupabaseClient _client;

  const DataExportRemoteDataSourceImpl(this._client);

  @override
  Future<UserDataSnapshot> readAll() async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('not_authenticated');

    // Row Level Security: each read returns only the rows of this user.
    final truncated = <String>{};

    final profile =
        await _client.from('profiles').select().eq('id', user.id).maybeSingle();
    final settings = await _client
        .from('user_settings')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    return UserDataSnapshot(
      userId: user.id,
      email: user.email,
      profile: profile,
      settings: settings,
      workspaces: await _readTable('workspaces', 'id', truncated),
      accounts: await _readTable('accounts', 'id', truncated),
      cardDetails: await _readTable('credit_card_details', 'account_id', truncated),
      invoices: await _readTable('credit_card_invoices', 'id', truncated),
      categories: await _readTable('categories', 'id', truncated),
      budgets: await _readTable('budgets', 'id', truncated),
      recurring: await _readTable('recurring_transactions', 'id', truncated),
      transactions: await _readTable('transactions', 'id', truncated),
      transfers: await _readTable('transfers', 'id', truncated),
      truncatedTables: truncated,
    );
  }

  /// Every row of [table], a page at a time, in a stable order.
  Future<List<Map<String, dynamic>>> _readTable(
    String table,
    String orderBy,
    Set<String> truncated,
  ) async {
    final rows = <Map<String, dynamic>>[];
    var from = 0;

    while (true) {
      final page = await _client
          .from(table)
          .select()
          .order(orderBy)
          .range(from, from + pageSize - 1);

      rows.addAll(page);
      if (page.length < pageSize) break;
      if (rows.length >= maxRowsPerTable) {
        truncated.add(table);
        break;
      }
      from += pageSize;
    }
    return rows;
  }
}
