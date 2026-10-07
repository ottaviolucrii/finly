import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class TransactionMoveRemoteDataSource {
  Future<void> moveTransaction(String transactionId, String accountId);
}

class TransactionMoveRemoteDataSourceImpl implements TransactionMoveRemoteDataSource {
  final SupabaseClient _client;

  const TransactionMoveRemoteDataSourceImpl(this._client);

  @override
  Future<void> moveTransaction(String transactionId, String accountId) async {
    // Database function (sql/15_move_transaction.sql): the rules are checked
    // there, and the balances of both accounts follow by themselves.
    await _client.rpc(
      'move_transaction',
      params: {'p_transaction_id': transactionId, 'p_account_id': accountId},
    );
  }
}
