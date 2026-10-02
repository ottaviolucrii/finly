import 'package:finly/features/auth/data/models/user_model.dart';
import 'package:finly/features/auth/domain/entities/sign_up_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class AuthRemoteDataSource {
  Future<UserModel> signIn({required String email, required String password});

  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String fullName,
  });

  Future<void> signOut({required bool allDevices});

  Future<UserModel> switchWorkspace(String workspaceId);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient _client;

  const AuthRemoteDataSourceImpl(this._client);

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) throw const AuthException('invalid_credentials');
    return _loadUser(user.id, user.email ?? email);
  }

  @override
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName}, // read by the profile trigger
    );

    // With e-mail confirmation on, there is no session until the e-mail is
    // verified. If the address already exists, Supabase answers the same way
    // (on purpose), so the app never reveals which e-mails are registered.
    final user = response.user;
    final session = response.session;
    if (session == null || user == null) {
      return SignUpResult(email: email, needsEmailVerification: true);
    }
    return SignUpResult(
      email: email,
      needsEmailVerification: false,
      user: await _loadUser(user.id, user.email ?? email),
    );
  }

  @override
  Future<void> signOut({required bool allDevices}) {
    return _client.auth.signOut(
      scope: allDevices ? SignOutScope.global : SignOutScope.local,
    );
  }

  @override
  Future<UserModel> switchWorkspace(String workspaceId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('not_authenticated');

    await _client.rpc(
      'switch_workspace',
      params: {'p_workspace_id': workspaceId},
    );
    return _loadUser(user.id, user.email ?? '');
  }

  Future<UserModel> _loadUser(String id, String email) async {
    final profile =
        await _client.from('profiles').select().eq('id', id).single();
    final workspaces = await _client
        .from('workspaces')
        .select()
        .eq('owner_id', id)
        .order('created_at');

    return UserModel.fromMap(
      profile: profile,
      email: email,
      workspaces: workspaces,
    );
  }
}