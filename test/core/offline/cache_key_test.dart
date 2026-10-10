import 'dart:convert';

import 'package:finly/core/offline/cache_key.dart';
import 'package:flutter_test/flutter_test.dart';

/// A JWT with the given claims. The signature is not checked here.
String jwt(Map<String, Object?> claims) {
  String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part(claims)}.signature';
}

void main() {
  group('userIdFromAuthorization', () {
    test('reads the user of a signed-in token', () {
      final header = 'Bearer ${jwt({'sub': 'user-1', 'role': 'authenticated'})}';

      expect(userIdFromAuthorization(header), 'user-1');
    });

    test('accepts "bearer" in lower case', () {
      expect(userIdFromAuthorization('bearer ${jwt({'sub': 'user-1'})}'), 'user-1');
    });

    test('the public key has no user', () {
      expect(userIdFromAuthorization('Bearer ${jwt({'role': 'anon'})}'), isNull);
    });

    test('an empty user is no user', () {
      expect(userIdFromAuthorization('Bearer ${jwt({'sub': ''})}'), isNull);
    });

    test('a user that is not text is no user', () {
      expect(userIdFromAuthorization('Bearer ${jwt({'sub': 42})}'), isNull);
    });

    test('no header, no user', () {
      expect(userIdFromAuthorization(null), isNull);
      expect(userIdFromAuthorization(''), isNull);
    });

    test('something that is not a bearer token is no user', () {
      expect(userIdFromAuthorization('Basic abc'), isNull);
      expect(userIdFromAuthorization('Bearer'), isNull);
      expect(userIdFromAuthorization('Bearer not-a-jwt'), isNull);
      expect(userIdFromAuthorization('Bearer a.b'), isNull);
    });

    test('a token with a body that is not JSON is no user', () {
      final body = base64Url.encode(utf8.encode('not json')).replaceAll('=', '');

      expect(userIdFromAuthorization('Bearer abc.$body.sig'), isNull);
    });
  });

  group('cacheKeyFor', () {
    final url = Uri.parse('https://x.supabase.co/rest/v1/accounts?select=*&order=name');

    String key({String method = 'GET', Uri? address, Map<String, String> headers = const {}}) {
      return cacheKeyFor(method: method, url: address ?? url, headers: headers);
    }

    test('is 16 characters of a file name', () {
      expect(key(), matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('is the same for the same request', () {
      expect(key(), key());
    });

    test('is another for another address', () {
      expect(key(), isNot(key(address: Uri.parse('https://x.supabase.co/rest/v1/categories?select=*'))));
    });

    test('is another for another filter in the same address', () {
      final a = Uri.parse('https://x.supabase.co/rest/v1/transactions?month=eq.2026-09-01');
      final b = Uri.parse('https://x.supabase.co/rest/v1/transactions?month=eq.2026-10-01');

      expect(key(address: a), isNot(key(address: b)));
    });

    test('is another when one row is asked instead of a list', () {
      expect(
        key(headers: {'Accept': 'application/vnd.pgrst.object+json'}),
        isNot(key(headers: {'Accept': 'application/json'})),
      );
    });

    test('is another for another page', () {
      expect(key(headers: {'Range': '0-49'}), isNot(key(headers: {'Range': '50-99'})));
    });

    test('is another when a count is asked', () {
      expect(key(headers: {'Prefer': 'count=exact'}), isNot(key()));
    });

    test('does not depend on how the headers are written', () {
      expect(key(headers: {'ACCEPT': 'application/json'}), key(headers: {'accept': 'application/json'}));
    });

    test('does not depend on the token, so a renewed token finds the same copy', () {
      expect(
        key(headers: {'Authorization': 'Bearer one', 'apikey': 'k1'}),
        key(headers: {'Authorization': 'Bearer two', 'apikey': 'k2'}),
      );
    });

    test('does not depend on the case of the method', () {
      expect(key(method: 'get'), key(method: 'GET'));
    });
  });
}
