import 'package:finly/features/recurring/domain/entities/recurring_suggestion.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Where the suggestions come from.
abstract class RecurringSuggestionSource {
  Future<List<RecurringSuggestion>> suggestions(String workspaceId);

  /// The ones the person closed with "Agora não" (by [RecurringSuggestion.key]).
  Future<Set<String>> dismissed(String workspaceId);

  Future<void> dismiss(String workspaceId, RecurringSuggestion suggestion);
}

/// Reads them from the database (the person's own history) and keeps the
/// closed ones on the phone. A suggestion is never worth an error message, so
/// a failure just means none.
class SupabaseRecurringSuggestionSource implements RecurringSuggestionSource {
  final SupabaseClient _client;

  const SupabaseRecurringSuggestionSource(this._client);

  String _key(String workspaceId) => 'recurring_suggestions.dismissed.$workspaceId';

  @override
  Future<List<RecurringSuggestion>> suggestions(String workspaceId) async {
    try {
      final rows = await _client.rpc('suggest_recurring', params: {'p_workspace': workspaceId});
      return [for (final row in (rows as List)) RecurringSuggestion.fromMap(Map<String, dynamic>.from(row as Map))];
    } catch (e) {
      debugPrint('Recurring suggestions failed: $e');
      return const [];
    }
  }

  @override
  Future<Set<String>> dismissed(String workspaceId) async =>
      ((await SharedPreferences.getInstance()).getStringList(_key(workspaceId)) ?? const <String>[]).toSet();

  @override
  Future<void> dismiss(String workspaceId, RecurringSuggestion suggestion) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = {...?prefs.getStringList(_key(workspaceId)), suggestion.key};
    await prefs.setStringList(_key(workspaceId), keys.toList());
  }
}
