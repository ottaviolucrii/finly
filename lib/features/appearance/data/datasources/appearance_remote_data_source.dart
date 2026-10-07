import 'package:finly/features/appearance/domain/entities/appearance_mode.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class AppearanceRemoteDataSource {
  Future<AppearanceMode> getMode();

  Future<void> saveMode(AppearanceMode mode);
}

class AppearanceRemoteDataSourceImpl implements AppearanceRemoteDataSource {
  final SupabaseClient _client;

  const AppearanceRemoteDataSourceImpl(this._client);

  String _userId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AuthException('not_authenticated');
    return id;
  }

  @override
  Future<AppearanceMode> getMode() async {
    // Row Level Security: a user reads and changes only their own row.
    final row = await _client
        .from('user_settings')
        .select('theme')
        .eq('user_id', _userId())
        .single();

    return AppearanceMode.fromDb(row['theme'] as String?);
  }

  @override
  Future<void> saveMode(AppearanceMode mode) async {
    await _client
        .from('user_settings')
        .update({'theme': mode.dbValue})
        .eq('user_id', _userId());
  }
}
