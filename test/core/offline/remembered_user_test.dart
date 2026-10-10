import 'package:finly/core/offline/remembered_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const session = '{"access_token":"a","refresh_token":"r","expires_at":1,'
      '"user":{"id":"user-1","email":"ana@example.com"}}';

  group('knownUserFromSession', () {
    test('reads who is in a saved session', () {
      expect(
        knownUserFromSession(session),
        const KnownUser(id: 'user-1', email: 'ana@example.com'),
      );
    });

    test('a session with no e-mail has an empty one', () {
      expect(
        knownUserFromSession('{"user":{"id":"user-1"}}'),
        const KnownUser(id: 'user-1', email: ''),
      );
    });

    test('no text, no one', () {
      expect(knownUserFromSession(null), isNull);
      expect(knownUserFromSession(''), isNull);
    });

    test('text that is not JSON is no one', () {
      expect(knownUserFromSession('not json'), isNull);
    });

    test('JSON that is not a session is no one', () {
      expect(knownUserFromSession('[]'), isNull);
      expect(knownUserFromSession('{}'), isNull);
      expect(knownUserFromSession('{"user":"x"}'), isNull);
    });

    test('a user with no id is no one', () {
      expect(knownUserFromSession('{"user":{"email":"a@b.com"}}'), isNull);
      expect(knownUserFromSession('{"user":{"id":""}}'), isNull);
      expect(knownUserFromSession('{"user":{"id":42}}'), isNull);
    });
  });

  group('sessionStorageKeyFor', () {
    test('is made from the address of the project, like the library does', () {
      expect(
        sessionStorageKeyFor('https://qcdlisdlizkmxmkoedar.supabase.co'),
        'sb-qcdlisdlizkmxmkoedar-auth-token',
      );
    });

    test('ignores the path', () {
      expect(sessionStorageKeyFor('https://abc.supabase.co/rest/v1'), 'sb-abc-auth-token');
    });
  });

  group('PreferencesSessionMemory', () {
    const key = 'sb-abc-auth-token';

    test('gives the saved session', () async {
      SharedPreferences.setMockInitialValues({key: session});

      expect(await PreferencesSessionMemory(key).raw(), session);
    });

    test('gives nothing when there is none', () async {
      SharedPreferences.setMockInitialValues({});

      expect(await PreferencesSessionMemory(key).raw(), isNull);
      expect(await PreferencesSessionMemory(key).user(), isNull);
    });

    test('says who is signed in', () async {
      SharedPreferences.setMockInitialValues({key: session});

      expect(
        await PreferencesSessionMemory(key).user(),
        const KnownUser(id: 'user-1', email: 'ana@example.com'),
      );
    });

    test('sees a session that was saved after it was first read', () async {
      SharedPreferences.setMockInitialValues({});
      final memory = PreferencesSessionMemory(key);
      expect(await memory.raw(), isNull);

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(key, session);

      expect(await memory.raw(), session);
    });

    test('sees that the session was removed (the person signed out)', () async {
      SharedPreferences.setMockInitialValues({key: session});
      final memory = PreferencesSessionMemory(key);
      expect(await memory.user(), isNotNull);

      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(key);

      expect(await memory.user(), isNull);
    });

    test('ignores the other things saved on the phone', () async {
      SharedPreferences.setMockInitialValues({'other': session});

      expect(await PreferencesSessionMemory(key).raw(), isNull);
    });
  });

  test('nobody is remembered until main says where to look', () {
    expect(RememberedSession.memory, isNull);
  });
}
