import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/ai/domain/entities/ai_draft.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// An answer of the function that is not a draft: [code] says why
/// (ai_disabled, ai_limit, ai_not_understood, ai_unavailable...).
class AiException implements Exception {
  final String code;

  const AiException(this.code);

  @override
  String toString() => 'AiException($code)';
}

/// "2026-10-11" for the day of [date].
String dayText(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// The body sent to the function: the sentence, today, and only the names
/// (and kinds) of the categories and accounts.
Map<String, dynamic> aiRequestBody({
  required String text,
  required DateTime today,
  required List<CategoryEntity> categories,
  required List<AccountEntity> accounts,
}) {
  return {
    'text': text.trim(),
    'today': dayText(today),
    'categories': [
      for (final category in categories)
        if (!category.isArchived)
          {
            'id': category.id,
            'name': category.name,
            'kind': category.kind == CategoryKind.income ? 'income' : 'expense',
          },
    ],
    'accounts': [
      for (final account in accounts)
        {'id': account.id, 'name': account.name, 'card': account.type == AccountType.creditCard},
    ],
  };
}

abstract class AiRemoteDataSource {
  Future<AiDraft> readSentence({
    required String text,
    required DateTime today,
    required List<CategoryEntity> categories,
    required List<AccountEntity> accounts,
  });

  Future<bool> isEnabled();

  Future<void> setEnabled(bool enabled);
}

class AiRemoteDataSourceImpl implements AiRemoteDataSource {
  final SupabaseClient _client;

  const AiRemoteDataSourceImpl(this._client);

  static const functionName = 'ai-parse-transaction';

  @override
  Future<AiDraft> readSentence({
    required String text,
    required DateTime today,
    required List<CategoryEntity> categories,
    required List<AccountEntity> accounts,
  }) async {
    try {
      final response = await _client.functions.invoke(
        functionName,
        body: aiRequestBody(text: text, today: today, categories: categories, accounts: accounts),
      );
      final data = response.data;
      if (data is Map && data['draft'] is Map) {
        return AiDraft.fromJson(Map<String, dynamic>.from(data['draft'] as Map), fallbackDate: today);
      }
      throw const AiException('ai_not_understood');
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map && details['error'] is String ? details['error'] as String : 'ai_unavailable';
      throw AiException(code);
    }
  }

  @override
  Future<bool> isEnabled() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final row = await _client.from('ai_settings').select('enabled').eq('user_id', uid).maybeSingle();
    return row?['enabled'] == true;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AiException('not_authenticated');
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('ai_settings').upsert({
      'user_id': uid,
      'enabled': enabled,
      if (enabled) 'consented_at': now,
      'updated_at': now,
    });
  }
}
