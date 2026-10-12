import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The category the person usually picks for a description, from their own
/// history (no AI). Null when there is none, or when it cannot be asked now:
/// a suggestion is never worth an error message.
class CategorySuggestionSource {
  final SupabaseClient _client;

  const CategorySuggestionSource(this._client);

  Future<String?> suggest({
    required String workspaceId,
    required String description,
    required TransactionType type,
  }) async {
    final text = description.trim();
    if (text.length < 3 || (type != TransactionType.expense && type != TransactionType.income)) return null;
    try {
      final result = await _client.rpc('suggest_category', params: {
        'p_workspace': workspaceId,
        'p_description': text,
        'p_type': type == TransactionType.income ? 'income' : 'expense',
      });
      return result is String ? result : null;
    } catch (e) {
      debugPrint('Category suggestion failed: $e');
      return null;
    }
  }
}
