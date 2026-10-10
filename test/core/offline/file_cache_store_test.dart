import 'dart:io';

import 'package:finly/core/offline/cached_response.dart';
import 'package:finly/core/offline/cache_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('finly_cache_test');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
  });

  FileCacheStore build({int maxBytes = FileCacheStore.defaultMaxBytes, int checkEveryBytes = 1024 * 1024}) {
    return FileCacheStore(
      directory: () async => Directory('${root.path}/offline_cache'),
      maxBytes: maxBytes,
      checkEveryBytes: checkEveryBytes,
    );
  }

  CachedResponse copy(String body, {DateTime? savedAt}) {
    return CachedResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json'},
      body: body,
      savedAt: savedAt ?? DateTime(2026, 10, 9, 14, 32),
    );
  }

  test('a copy that was never made is not there', () async {
    expect(await build().read('user-1', 'abc'), isNull);
  });

  test('a copy that was written is read back', () async {
    final store = build();

    await store.write('user-1', 'abc', copy('[{"id":1}]'));

    expect(await store.read('user-1', 'abc'), copy('[{"id":1}]'));
  });

  test('is still there for another store on the same folder (after the app restarts)', () async {
    await build().write('user-1', 'abc', copy('[1]'));

    expect(await build().read('user-1', 'abc'), copy('[1]'));
  });

  test('a copy is replaced by a newer one', () async {
    final store = build();
    await store.write('user-1', 'abc', copy('[1]'));

    await store.write('user-1', 'abc', copy('[2]'));

    expect((await store.read('user-1', 'abc'))!.body, '[2]');
  });

  test('two users never see each other\'s copies', () async {
    final store = build();
    await store.write('user-1', 'abc', copy('[1]'));
    await store.write('user-2', 'abc', copy('[2]'));

    expect((await store.read('user-1', 'abc'))!.body, '[1]');
    expect((await store.read('user-2', 'abc'))!.body, '[2]');
    expect(await store.read('user-3', 'abc'), isNull);
  });

  test('a user id cannot make the copy leave its folder', () async {
    final store = build();

    await store.write('../escape', 'abc', copy('[1]'));

    expect(await store.read('../escape', 'abc'), isNotNull);
    expect(Directory('${root.path}/escape').existsSync(), isFalse);
    expect(Directory('${root.path}/offline_cache/___escape').existsSync(), isTrue);
  });

  test('leaves no half written file behind', () async {
    final store = build();

    await store.write('user-1', 'abc', copy('[1]'));

    final leftovers = Directory('${root.path}/offline_cache')
        .listSync(recursive: true)
        .where((entity) => entity.path.endsWith('.tmp'));
    expect(leftovers, isEmpty);
  });

  test('a copy that cannot be read is erased and counts as missing', () async {
    final store = build();
    await store.write('user-1', 'abc', copy('[1]'));
    final file = File('${root.path}/offline_cache/user-1/abc.json');
    file.writeAsStringSync('{"status": 200, "head');

    expect(await store.read('user-1', 'abc'), isNull);
    expect(file.existsSync(), isFalse);
  });

  group('size', () {
    test('is zero when nothing was kept', () async {
      expect(await build().sizeBytes(), 0);
    });

    test('grows with each copy', () async {
      final store = build();
      await store.write('user-1', 'a', copy('x' * 1000));
      final one = await store.sizeBytes();

      await store.write('user-1', 'b', copy('x' * 1000));

      expect(one, greaterThan(1000));
      expect(await store.sizeBytes(), greaterThan(one));
    });

    test('does not count the choice of turning copies off', () async {
      final store = build();
      await store.setEnabled(false);

      expect(await store.sizeBytes(), 0);
    });
  });

  group('clear', () {
    test('erases the copies of every user', () async {
      final store = build();
      await store.write('user-1', 'a', copy('[1]'));
      await store.write('user-2', 'a', copy('[2]'));

      await store.clear();

      expect(await store.read('user-1', 'a'), isNull);
      expect(await store.read('user-2', 'a'), isNull);
      expect(await store.sizeBytes(), 0);
    });

    test('works when there is nothing to erase', () async {
      await build().clear();
    });

    test('keeps the choice of turning copies off', () async {
      final store = build();
      await store.setEnabled(false);

      await store.clear();

      expect(await store.isEnabled(), isFalse);
    });

    test('lets new copies be written afterwards', () async {
      final store = build();
      await store.write('user-1', 'a', copy('[1]'));
      await store.clear();

      await store.write('user-1', 'a', copy('[2]'));

      expect((await store.read('user-1', 'a'))!.body, '[2]');
    });
  });

  group('turning copies on and off', () {
    test('is on at first', () async {
      expect(await build().isEnabled(), isTrue);
    });

    test('can be turned off and on', () async {
      final store = build();

      await store.setEnabled(false);
      expect(await store.isEnabled(), isFalse);

      await store.setEnabled(true);
      expect(await store.isEnabled(), isTrue);
    });

    test('is remembered after the app restarts', () async {
      await build().setEnabled(false);

      expect(await build().isEnabled(), isFalse);
    });
  });

  group('copiesToRemove', () {
    ({String path, int size, DateTime modified}) copyOf(String path, int size, int minutesAgo) {
      return (
        path: path,
        size: size,
        modified: DateTime(2026, 10, 9, 12).subtract(Duration(minutes: minutesAgo)),
      );
    }

    test('nothing while the copies fit', () {
      expect(copiesToRemove([copyOf('a', 400, 30), copyOf('b', 400, 20)], 1000), isEmpty);
    });

    test('nothing when they use exactly the limit', () {
      expect(copiesToRemove([copyOf('a', 500, 30), copyOf('b', 500, 20)], 1000), isEmpty);
    });

    test('nothing when there are no copies', () {
      expect(copiesToRemove(const [], 1000), isEmpty);
    });

    test('the oldest goes first, until the rest uses 80% of the limit', () {
      final copies = [copyOf('oldest', 400, 30), copyOf('middle', 400, 20), copyOf('newest', 400, 10)];

      expect(copiesToRemove(copies, 1000), ['oldest']);
    });

    test('more than one goes when one is not enough', () {
      final copies = [
        copyOf('a', 300, 50),
        copyOf('b', 300, 40),
        copyOf('c', 300, 30),
        copyOf('d', 300, 20),
        copyOf('e', 300, 10),
      ];

      expect(copiesToRemove(copies, 1000), ['a', 'b', 'c']);
    });

    test('does not depend on the order of the list', () {
      final copies = [copyOf('newest', 400, 10), copyOf('oldest', 400, 30), copyOf('middle', 400, 20)];

      expect(copiesToRemove(copies, 1000), ['oldest']);
    });

    test('a single copy over the limit goes', () {
      expect(copiesToRemove([copyOf('big', 2000, 5)], 1000), ['big']);
    });
  });

  group('limit', () {
    test('the oldest copy goes when the limit is passed, and the newest stays', () async {
      final store = build(maxBytes: 1024 * 1024, checkEveryBytes: 0);
      final big = 'x' * (400 * 1024);

      await store.write('user-1', 'oldest', copy(big));
      await store.write('user-1', 'middle', copy(big));
      // The order is set by hand: the clock of a disk is too coarse to trust
      // for two files written a moment apart.
      File('${root.path}/offline_cache/user-1/oldest.json')
          .setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));
      File('${root.path}/offline_cache/user-1/middle.json')
          .setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 1)));
      await store.write('user-1', 'newest', copy(big));

      expect(await store.sizeBytes(), lessThanOrEqualTo(1024 * 1024));
      expect(await store.read('user-1', 'oldest'), isNull);
      expect(await store.read('user-1', 'middle'), isNotNull);
      expect(await store.read('user-1', 'newest'), isNotNull);
    });

    test('nothing is removed while the copies fit', () async {
      final store = build(maxBytes: 1024 * 1024, checkEveryBytes: 0);

      await store.write('user-1', 'a', copy('x' * 1000));
      await store.write('user-1', 'b', copy('x' * 1000));

      expect(await store.read('user-1', 'a'), isNotNull);
      expect(await store.read('user-1', 'b'), isNotNull);
    });
  });
}
