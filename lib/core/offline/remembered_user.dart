import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Someone who is signed in on this phone.
class KnownUser extends Equatable {
  final String id;
  final String email;

  const KnownUser({required this.id, required this.email});

  @override
  List<Object?> get props => [id, email];
}

/// Who is in the session text the login library keeps on the phone. Null when
/// there is no session, or the text is not one.
KnownUser? knownUserFromSession(String? raw) {
  if (raw == null || raw.isEmpty) return null;

  try {
    final map = jsonDecode(raw);
    if (map is! Map<String, dynamic>) return null;

    final user = map['user'];
    if (user is! Map<String, dynamic>) return null;

    final id = user['id'];
    if (id is! String || id.isEmpty) return null;

    final email = user['email'];
    return KnownUser(id: id, email: email is String ? email : '');
  } catch (_) {
    return null;
  }
}

/// The name under which the login library keeps the session on the phone. It is
/// made from the address of the project, like the library does.
String sessionStorageKeyFor(String supabaseUrl) {
  return 'sb-${Uri.parse(supabaseUrl).host.split('.').first}-auth-token';
}

/// What the phone remembers of the session. The login library drops its own
/// copy when an expired login cannot be renewed (no internet), but the text it
/// saved on the phone stays, and says who was signed in.
abstract class SessionMemory {
  /// The saved session as text, or null when there is none (signing out
  /// removes it).
  Future<String?> raw();

  Future<KnownUser?> user() async => knownUserFromSession(await raw());
}

class PreferencesSessionMemory extends SessionMemory {
  final String _key;

  PreferencesSessionMemory(this._key);

  @override
  Future<String?> raw() async {
    final preferences = await SharedPreferences.getInstance();
    // Read again from the phone: the login library writes to it while the app runs.
    await preferences.reload();
    return preferences.getString(_key);
  }
}

/// Where the rest of the app finds the [SessionMemory] that `main` created.
abstract final class RememberedSession {
  static SessionMemory? memory;
}
