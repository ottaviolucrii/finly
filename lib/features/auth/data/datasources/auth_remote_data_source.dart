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

  /// The user of the stored session, or null when nobody is signed in.
  Future<UserModel?> currentUser();

  Future<UserModel> switchWorkspace(String workspaceId);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> deleteAccount({required String password});

  Future<void> requestPasswordReset({required String email});

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });
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
  Future<UserModel?> currentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return _loadUser(user.id, user.email ?? '');
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

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _confirmPassword(currentPassword);
    await _client.auth.updateUser(UserAttributes(password: newPassword));

    // A password change should end the sessions of every other device. The
    // password is already changed, so a failure here is not worth failing for.
    try {
      await _client.auth.signOut(scope: SignOutScope.others);
    } catch (_) {
      // Ignored on purpose.
    }
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    await _confirmPassword(password);

    // Database function (sql/03_logic.sql): erases the user and, by cascade,
    // every row they own, including the audit trail.
    await _client.rpc('delete_my_account');

    // The user no longer exists on the server; clear the local session.
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      // Ignored on purpose: the account is already gone.
    }
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    // Supabase answers the same way whether or not the e-mail has an account.
    // The "Reset Password" e-mail template must show {{ .Token }}.
    await _client.auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    // Checking the code signs the person in for a moment.
    await _client.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.recovery,
    );

    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      // A password reset should end the sessions of every other device.
      try {
        await _client.auth.signOut(scope: SignOutScope.others);
      } catch (_) {
        // Ignored on purpose: the password is already changed.
      }
    } finally {
      // The session from the code exists only for this change. It is always
      // cleared, even when the change failed, so nobody stays signed in
      // without having typed a password.
      try {
        await _client.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        // Ignored on purpose.
      }
    }
  }

  /// Signing in again proves the person at the keyboard knows the password,
  /// not only that the phone is unlocked.
  Future<void> _confirmPassword(String password) async {
    final user = _client.auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthException('not_authenticated');
    }
    await _client.auth.signInWithPassword(email: email, password: password);
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