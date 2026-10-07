import 'package:finly/features/lock/data/models/lock_settings_model.dart';
import 'package:finly/features/lock/domain/entities/lock_settings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class LockRemoteDataSource {
  Future<LockSettingsModel> getSettings();

  Future<void> saveSettings(LockSettings settings);

  Future<void> verifyPassword(String password);
}

class LockRemoteDataSourceImpl implements LockRemoteDataSource {
  final SupabaseClient _client;

  const LockRemoteDataSourceImpl(this._client);

  String _userId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AuthException('not_authenticated');
    return id;
  }

  @override
  Future<LockSettingsModel> getSettings() async {
    // Row Level Security: a user reads and changes only their own row.
    final row = await _client
        .from('user_settings')
        .select('lock_timeout_seconds, biometric_enabled')
        .eq('user_id', _userId())
        .single();

    return LockSettingsModel.fromMap(row);
  }

  @override
  Future<void> saveSettings(LockSettings settings) async {
    // The database accepts 0 to 900 seconds for the time.
    await _client
        .from('user_settings')
        .update({
          'lock_timeout_seconds': settings.timeoutSeconds,
          'biometric_enabled': settings.biometricEnabled,
        })
        .eq('user_id', _userId());
  }

  @override
  Future<void> verifyPassword(String password) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) throw const AuthException('not_authenticated');

    // Signing in again proves the person at the keyboard knows the password.
    await _client.auth.signInWithPassword(email: email, password: password);
  }
}