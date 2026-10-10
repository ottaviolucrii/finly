import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:finly/core/offline/cache_store.dart';
import 'package:finly/core/offline/cached_response.dart';
import 'package:finly/core/offline/caching_http_client.dart';
import 'package:finly/core/offline/offline_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A store in memory, so these tests are about the client and not about files.
class FakeStore implements CacheStore {
  final Map<String, CachedResponse> copies = {};
  bool enabled = true;
  bool failToWrite = false;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool value) async => enabled = value;

  @override
  Future<CachedResponse?> read(String userId, String key) async => copies['$userId/$key'];

  @override
  Future<void> write(String userId, String key, CachedResponse response) async {
    if (failToWrite) throw const FileSystemException('disk full');
    copies['$userId/$key'] = response;
  }

  @override
  Future<int> sizeBytes() async => copies.length;

  @override
  Future<void> clear() async => copies.clear();
}

String jwt(Map<String, Object?> claims) {
  String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part(claims)}.signature';
}

void main() {
  late FakeStore store;
  late OfflineStatus status;
  late int calls;
  late String answer;
  late int answerStatus;
  late Object? failure;
  late Duration? delay;
  late DateTime now;

  final tokenOfUser1 = jwt({'sub': 'user-1', 'role': 'authenticated'});
  final tokenOfUser2 = jwt({'sub': 'user-2', 'role': 'authenticated'});
  final publicKey = jwt({'role': 'anon'});

  setUp(() {
    store = FakeStore();
    status = OfflineStatus();
    calls = 0;
    answer = '[{"id":1,"name":"Conta"}]';
    answerStatus = 200;
    failure = null;
    delay = null;
    now = DateTime(2026, 10, 9, 14, 32);
  });

  CachingHttpClient build({
    Duration slowAfter = const Duration(seconds: 6),
    Future<String?> Function()? rememberedUserId,
    Future<void> Function()? restoreSession,
  }) {
    final inner = MockClient((request) async {
      calls++;
      final wait = delay;
      if (wait != null) await Future<void>.delayed(wait);
      final error = failure;
      if (error != null) throw error;
      return http.Response(
        answer,
        answerStatus,
        headers: {'content-type': 'application/json; charset=utf-8', 'content-range': '0-0/1', 'x-other': 'no'},
      );
    });
    return CachingHttpClient(
      inner: inner,
      store: store,
      status: status,
      slowAfter: slowAfter,
      clock: () => now,
      rememberedUserId: rememberedUserId,
      restoreSession: restoreSession,
    );
  }

  Uri rest([String table = 'accounts']) => Uri.https('x.supabase.co', '/rest/v1/$table', {'select': '*'});

  Map<String, String> as(String token, {Map<String, String> more = const {}}) {
    return {'Authorization': 'Bearer $token', 'apikey': 'key', ...more};
  }

  group('a read that works', () {
    test('answers with what the server said', () async {
      final client = build();

      final response = await client.get(rest(), headers: as(tokenOfUser1));

      expect(response.statusCode, 200);
      expect(response.body, answer);
      expect(calls, 1);
    });

    test('keeps a copy for the user', () async {
      final client = build();

      await client.get(rest(), headers: as(tokenOfUser1));
      await pumpEventQueue();

      expect(store.copies, hasLength(1));
      expect(store.copies.keys.single, startsWith('user-1/'));
      final copy = store.copies.values.single;
      expect(copy.body, answer);
      expect(copy.statusCode, 200);
      expect(copy.savedAt, now);
    });

    test('keeps only the headers a read needs', () async {
      final client = build();

      await client.get(rest(), headers: as(tokenOfUser1));
      await pumpEventQueue();

      final headers = store.copies.values.single.headers;
      expect(headers['content-type'], 'application/json; charset=utf-8');
      expect(headers['content-range'], '0-0/1');
      expect(headers.containsKey('x-other'), isFalse);
    });

    test('keeps accents of the data', () async {
      answer = '[{"name":"Mercadão — café"}]';
      final client = build();

      final response = await client.get(rest(), headers: as(tokenOfUser1));
      await pumpEventQueue();

      expect(utf8.decode(response.bodyBytes), answer);
      expect(store.copies.values.single.body, answer);
    });

    test('does not go offline', () async {
      final client = build();

      await client.get(rest(), headers: as(tokenOfUser1));

      expect(status.isOffline, isFalse);
      expect(status.isBackOnline, isFalse);
    });

    test('a failure to keep the copy does not hurt the answer', () async {
      store.failToWrite = true;
      final client = build();

      final response = await client.get(rest(), headers: as(tokenOfUser1));
      await pumpEventQueue();

      expect(response.body, answer);
      expect(store.copies, isEmpty);
    });
  });

  group('a read with no connection', () {
    test('answers with the copy', () async {
      final client = build();
      await client.get(rest(), headers: as(tokenOfUser1));
      await pumpEventQueue();
      failure = const SocketException('no route to host');

      final response = await client.get(rest(), headers: as(tokenOfUser1));

      expect(response.statusCode, 200);
      expect(response.body, answer);
      expect(response.headers['x-finly-cache'], 'hit');
      expect(response.headers['content-range'], '0-0/1');
    });

    test('says it is offline, and how old the copy is', () async {
      final client = build();
      await client.get(rest(), headers: as(tokenOfUser1));
      await pumpEventQueue();
      failure = const SocketException('no route to host');
      now = DateTime(2026, 10, 9, 18);

      await client.get(rest(), headers: as(tokenOfUser1));

      expect(status.isOffline, isTrue);
      expect(status.cachedSince, DateTime(2026, 10, 9, 14, 32));
    });

    test('a client error of the http package counts as no connection too', () async {
      final client = build();
      await client.get(rest(), headers: as(tokenOfUser1));
      await pumpEventQueue();
      failure = http.ClientException('Connection closed before full header was received');

      final response = await client.get(rest(), headers: as(tokenOfUser1));

      expect(response.body, answer);
    });

    test('a timeout of the connection counts as no connection too', () async {
      final client = build();
      await client.get(rest(), headers: as(tokenOfUser1));
      await pumpEventQueue();
      failure = TimeoutException('connection timed out');

      final response = await client.get(rest(), headers: as(tokenOfUser1));

      expect(response.body, answer);
    });

    test('with no copy, the failure goes to the screen as it always did', () async {
      failure = const SocketException('no route to host');
      final client = build();

      await expectLater(
        client.get(rest(), headers: as(tokenOfUser1)),
        throwsA(isA<SocketException>()),
      );
      expect(status.isOffline, isTrue);
    });

    test('a timeout with no copy is a failure, not a crash', () async {
      failure = TimeoutException('connection timed out');
      final client = build();

      await expectLater(
        client.get(rest(), headers: as(tokenOfUser1)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('an error of the program is not hidden by a copy', () async {
      final client = build();
      await client.get(rest(), headers: as(tokenOfUser1));
      await pumpEventQueue();
      failure = StateError('a bug');

      await expectLater(
        client.get(rest(), headers: as(tokenOfUser1)),
        throwsA(isA<StateError>()),
      );
      expect(status.isOffline, isFalse);
    });

    test('the copy of one address is not used for another', () async {
      final client = build();
      await client.get(rest('accounts'), headers: as(tokenOfUser1));
      await pumpEventQueue();
      failure = const SocketException('no route to host');

      await expectLater(
        client.get(rest('categories'), headers: as(tokenOfUser1)),
        throwsA(isA<SocketException>()),
      );
    });

    test('one row and a list of rows have their own copies', () async {
      final client = build();
      await client.get(rest(), headers: as(tokenOfUser1, more: {'Accept': 'application/vnd.pgrst.object+json'}));
      await pumpEventQueue();
      failure = const SocketException('no route to host');

      await expectLater(
        client.get(rest(), headers: as(tokenOfUser1, more: {'Accept': 'application/json'})),
        throwsA(isA<SocketException>()),
      );
    });

    test('a renewed token finds the same copy', () async {
      final client = build();
      await client.get(rest(), headers: as(jwt({'sub': 'user-1', 'exp': 1})));
      await pumpEventQueue();
      failure = const SocketException('no route to host');

      final response = await client.get(rest(), headers: as(jwt({'sub': 'user-1', 'exp': 2})));

      expect(response.body, answer);
    });

    test('another user never gets the copy of the first', () async {
      final client = build();
      await client.get(rest(), headers: as(tokenOfUser1));
      await pumpEventQueue();
      failure = const SocketException('no route to host');

      await expectLater(
        client.get(rest(), headers: as(tokenOfUser2)),
        throwsA(isA<SocketException>()),
      );
    });
  });

  group('when the server is slow', () {
    test('shows the copy instead of waiting', () async {
      final client = build(slowAfter: const Duration(milliseconds: 30));
      await client.get(rest(), headers: as(tokenOfUser1));
      await pumpEventQueue();
      delay = const Duration(milliseconds: 250);
      answer = '[{"id":2}]';

      final response = await client.get(rest(), headers: as(tokenOfUser1));

      expect(response.body, '[{"id":1,"name":"Conta"}]');
      expect(status.isOffline, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 350));
    });

    test('updates the copy and says the internet is back when the answer arrives', () async {
      final client = build(slowAfter: const Duration(milliseconds: 30));
      await client.get(rest(), headers: as(tokenOfUser1));
      await pumpEventQueue();
      delay = const Duration(milliseconds: 150);
      answer = '[{"id":2}]';
      await client.get(rest(), headers: as(tokenOfUser1));

      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(store.copies.values.single.body, '[{"id":2}]');
      expect(status.isOffline, isFalse);
      expect(status.isBackOnline, isTrue);
    });

    test('with no copy, waits for the answer', () async {
      final client = build(slowAfter: const Duration(milliseconds: 30));
      delay = const Duration(milliseconds: 120);

      final response = await client.get(rest(), headers: as(tokenOfUser1));

      expect(response.body, answer);
      expect(status.isOffline, isFalse);
    });

    test('a failure that arrives late is not reported as unhandled', () async {
      final client = build(slowAfter: const Duration(milliseconds: 30));
      await client.get(rest(), headers: as(tokenOfUser1));
      await pumpEventQueue();
      delay = const Duration(milliseconds: 100);
      failure = const SocketException('lost it');

      final response = await client.get(rest(), headers: as(tokenOfUser1));
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(response.body, answer);
    });
  });

  group('what is never copied', () {
    test('an answer of error', () async {
      answerStatus = 500;
      answer = '{"message":"boom"}';
      final client = build();

      final response = await client.get(rest(), headers: as(tokenOfUser1));
      await pumpEventQueue();

      expect(response.statusCode, 500);
      expect(store.copies, isEmpty);
    });

    test('an answer that says no (not allowed)', () async {
      answerStatus = 401;
      final client = build();

      await client.get(rest(), headers: as(tokenOfUser1));
      await pumpEventQueue();

      expect(store.copies, isEmpty);
    });

    test('a request without a signed-in user', () async {
      final client = build();

      await client.get(rest(), headers: as(publicKey));
      await client.get(rest());
      await pumpEventQueue();

      expect(store.copies, isEmpty);
    });

    test('something that changes data', () async {
      final client = build();

      for (final send in [
        () => client.post(rest('transactions'), headers: as(tokenOfUser1), body: '{}'),
        () => client.patch(rest('transactions'), headers: as(tokenOfUser1), body: '{}'),
        () => client.delete(rest('transactions'), headers: as(tokenOfUser1)),
      ]) {
        await send();
      }
      await pumpEventQueue();

      expect(store.copies, isEmpty);
      expect(calls, 3);
    });

    test('a call to a database function', () async {
      final client = build();

      await client.post(Uri.https('x.supabase.co', '/rest/v1/rpc/switch_workspace'), headers: as(tokenOfUser1), body: '{}');
      await pumpEventQueue();

      expect(store.copies, isEmpty);
    });

    test('the sign-in service', () async {
      final client = build();

      await client.get(Uri.https('x.supabase.co', '/auth/v1/user'), headers: as(tokenOfUser1));
      await pumpEventQueue();

      expect(store.copies, isEmpty);
    });

    test('anything when the copies are turned off', () async {
      store.enabled = false;
      final client = build();

      await client.get(rest(), headers: as(tokenOfUser1));
      await pumpEventQueue();

      expect(store.copies, isEmpty);
    });
  });

  group('what changes data has no copy to fall back on', () {
    test('a write with no connection fails, and says it is offline', () async {
      failure = const SocketException('no route to host');
      final client = build();

      await expectLater(
        client.post(rest('transactions'), headers: as(tokenOfUser1), body: '{}'),
        throwsA(isA<SocketException>()),
      );
      expect(status.isOffline, isTrue);
    });

    test('a write that works tells the app the connection is there', () async {
      status.markOffline();
      final client = build();

      await client.post(rest('transactions'), headers: as(tokenOfUser1), body: '{}');

      expect(status.isOffline, isFalse);
      expect(status.isBackOnline, isTrue);
    });

    test('when the copies are turned off, a read fails as it always did', () async {
      store.enabled = false;
      failure = const SocketException('no route to host');
      final client = build();

      await expectLater(
        client.get(rest(), headers: as(tokenOfUser1)),
        throwsA(isA<SocketException>()),
      );
    });

    test('a read that never had a copy still says the app is offline', () async {
      failure = const SocketException('no route to host');
      final client = build();

      await expectLater(client.get(rest(), headers: as(tokenOfUser1)), throwsA(isA<SocketException>()));

      expect(status.isOffline, isTrue);
      expect(status.cachedSince, isNull);
    });
  });

  group('coming back', () {
    test('after a time offline, the next answer says the internet is back', () async {
      final client = build();
      await client.get(rest(), headers: as(tokenOfUser1));
      await pumpEventQueue();
      failure = const SocketException('no route to host');
      await client.get(rest(), headers: as(tokenOfUser1));
      expect(status.isOffline, isTrue);

      failure = null;
      await client.get(rest(), headers: as(tokenOfUser1));

      expect(status.isOffline, isFalse);
      expect(status.isBackOnline, isTrue);
    });
  });

  group('no signed-in session, but the phone remembers who was signed in', () {
    late int restores;

    setUp(() => restores = 0);

    /// A client that already has a copy of the accounts for user-1.
    Future<CachingHttpClient> withCopy({
      Future<String?> Function()? remembered,
      Future<void> Function()? restore,
    }) async {
      final client = build(
        rememberedUserId: remembered ?? () async => 'user-1',
        restoreSession: restore ?? () async => restores++,
      );
      await client.get(rest(), headers: as(tokenOfUser1));
      await pumpEventQueue();
      return client;
    }

    test('the copy of that person answers, without asking the server', () async {
      final client = await withCopy();
      answer = '[]';

      final response = await client.get(rest(), headers: as(publicKey));

      expect(response.body, '[{"id":1,"name":"Conta"}]');
      expect(response.headers['x-finly-cache'], 'hit');
      expect(calls, 1);
    });

    test('also when the request has no Authorization header at all', () async {
      final client = await withCopy();

      final response = await client.get(rest());

      expect(response.body, '[{"id":1,"name":"Conta"}]');
    });

    test('says it shows saved data, and how old', () async {
      final client = await withCopy();
      now = DateTime(2026, 10, 9, 18);

      await client.get(rest(), headers: as(publicKey));

      expect(status.isOffline, isTrue);
      expect(status.cachedSince, DateTime(2026, 10, 9, 14, 32));
    });

    test('starts to bring the login back', () async {
      final client = await withCopy();

      await client.get(rest(), headers: as(publicKey));

      expect(restores, 1);
    });

    test('a failure to bring the login back does not hurt the answer', () async {
      final client = await withCopy(restore: () async => throw StateError('no internet'));

      final response = await client.get(rest(), headers: as(publicKey));
      await pumpEventQueue();

      expect(response.body, '[{"id":1,"name":"Conta"}]');
    });

    test('with no copy of that address, the server is asked as it is', () async {
      final client = await withCopy();

      await client.get(rest('categories'), headers: as(publicKey));

      expect(calls, 2);
    });

    test('what the server answers without a login is never kept', () async {
      final client = await withCopy();
      answer = '[]';

      await client.get(rest('categories'), headers: as(publicKey));
      await pumpEventQueue();

      expect(store.copies, hasLength(1));
      expect(store.copies.values.single.body, '[{"id":1,"name":"Conta"}]');
    });

    test('when nobody is remembered, it goes to the server as before', () async {
      final client = await withCopy(remembered: () async => null);

      await client.get(rest(), headers: as(publicKey));

      expect(calls, 2);
      expect(restores, 0);
    });

    test('a failure to find who is remembered is not a crash', () async {
      final client = await withCopy(remembered: () async => throw StateError('no preferences'));

      final response = await client.get(rest(), headers: as(publicKey));

      expect(response.statusCode, 200);
      expect(calls, 2);
    });

    test('the copy of someone else is never used', () async {
      final client = await withCopy(remembered: () async => 'user-2');

      await client.get(rest(), headers: as(publicKey));

      expect(calls, 2);
    });

    test('a read with a login still goes to the server first', () async {
      final client = await withCopy();
      answer = '[{"id":2}]';

      final response = await client.get(rest(), headers: as(tokenOfUser1));

      expect(response.body, '[{"id":2}]');
      expect(calls, 2);
      expect(restores, 0);
    });

    test('something that changes data is never answered from a copy', () async {
      final client = await withCopy();

      await client.post(rest('transactions'), headers: as(publicKey), body: '{}');

      expect(calls, 2);
    });

    test('nothing is answered from a copy when the copies are turned off', () async {
      final client = await withCopy();
      store.enabled = false;

      await client.get(rest(), headers: as(publicKey));

      expect(calls, 2);
    });
  });
}
