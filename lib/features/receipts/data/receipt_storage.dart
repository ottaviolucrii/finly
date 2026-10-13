import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Where receipt photos are kept: a private bucket, in a folder of the person
/// (only they can read it, see sql/05_storage.sql).
abstract class ReceiptStorage {
  /// Keeps [jpeg] as the receipt of [transaction] (replacing the old one) and
  /// returns its path.
  Future<String> attach(TransactionEntity transaction, Uint8List jpeg);

  /// A link to see the photo, valid for a while.
  Future<String> link(String path);

  /// Removes the receipt of [transaction].
  Future<void> remove(TransactionEntity transaction);
}

class SupabaseReceiptStorage implements ReceiptStorage {
  final SupabaseClient _client;

  const SupabaseReceiptStorage(this._client);

  static const bucket = 'receipts';

  @override
  Future<String> attach(TransactionEntity transaction, Uint8List jpeg) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AuthException('not_authenticated');
    final path = '$uid/${transaction.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage
        .from(bucket)
        .uploadBinary(path, jpeg, fileOptions: const FileOptions(contentType: 'image/jpeg'));
    await _client.from('transactions').update({'receipt_path': path}).eq('id', transaction.id);
    final old = transaction.receiptPath;
    if (old != null && old.isNotEmpty && old != path) await _forget(old);
    return path;
  }

  @override
  Future<String> link(String path) => _client.storage.from(bucket).createSignedUrl(path, 3600);

  @override
  Future<void> remove(TransactionEntity transaction) async {
    final path = transaction.receiptPath;
    await _client.from('transactions').update({'receipt_path': null}).eq('id', transaction.id);
    if (path != null && path.isNotEmpty) await _forget(path);
  }

  /// Deletes a photo no longer used; failing to is not an error for the person.
  Future<void> _forget(String path) async {
    try {
      await _client.storage.from(bucket).remove([path]);
    } catch (e) {
      debugPrint('Old receipt not deleted: $e');
    }
  }
}
