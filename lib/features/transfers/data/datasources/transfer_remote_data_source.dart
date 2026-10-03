import 'package:finly/features/transfers/domain/entities/transfer_kind.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class TransferRemoteDataSource {
  Future<String> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required int amountCents,
    int? toAmountCents,
    required String description,
    required DateTime occurredAt,
    required TransferKind kind,
  });

  Future<void> deleteTransfer(String transferId);
}

class TransferRemoteDataSourceImpl implements TransferRemoteDataSource {
  final SupabaseClient _client;

  const TransferRemoteDataSourceImpl(this._client);

  @override
  Future<String> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required int amountCents,
    int? toAmountCents,
    required String description,
    required DateTime occurredAt,
    required TransferKind kind,
  }) async {
    // Database function (sql/03_logic.sql): checks that both accounts belong
    // to the signed-in user, applies the rules of each kind, and creates the
    // two entries in one operation.
    final id = await _client.rpc(
      'create_transfer',
      params: {
        'p_from_account': fromAccountId,
        'p_to_account': toAccountId,
        'p_amount_cents': amountCents,
        'p_description': description,
        'p_occurred_at': occurredAt.toUtc().toIso8601String(),
        'p_kind': kind.dbValue,
        'p_to_amount_cents': toAmountCents,
        'p_status': 'posted',
      },
    );
    return id as String;
  }

  @override
  Future<void> deleteTransfer(String transferId) async {
    await _client.rpc('delete_transfer', params: {'p_transfer_id': transferId});
  }
}