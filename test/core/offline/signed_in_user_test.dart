import 'package:finly/core/offline/remembered_user.dart';
import 'package:finly/core/offline/signed_in_user.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeMemory extends SessionMemory {
  final String? text;
  final Object? failure;
  int reads = 0;

  FakeMemory(this.text, {this.failure});

  @override
  Future<String?> raw() async {
    reads++;
    final error = failure;
    if (error != null) throw error;
    return text;
  }
}

void main() {
  const fromLibrary = KnownUser(id: 'library-user', email: 'lib@example.com');
  const session = '{"user":{"id":"saved-user","email":"saved@example.com"}}';

  Future<SignedInUser?> resolve({
    required KnownUser? Function() library,
    SessionMemory? memory,
  }) {
    return resolveSignedInUser(
      fromLibrary: library,
      memory: memory,
      patience: const Duration(milliseconds: 60),
      step: const Duration(milliseconds: 10),
    );
  }

  test('the library comes first, and the phone is not even asked', () async {
    final memory = FakeMemory(session);

    final who = await resolve(library: () => fromLibrary, memory: memory);

    expect(who!.user, fromLibrary);
    expect(who.source, UserSource.library);
    expect(memory.reads, 0);
  });

  test('nobody is signed in when the library has none and nothing was saved', () async {
    final watch = Stopwatch()..start();

    final who = await resolve(library: () => null, memory: FakeMemory(null));

    expect(who, isNull);
    // No reason to wait when there is nobody to wait for.
    expect(watch.elapsedMilliseconds, lessThan(50));
  });

  test('nobody is signed in when main did not say where to look', () async {
    expect(await resolve(library: () => null), isNull);
  });

  test('uses the person the phone remembers when the library never gets a session', () async {
    final who = await resolve(library: () => null, memory: FakeMemory(session));

    expect(who!.user, const KnownUser(id: 'saved-user', email: 'saved@example.com'));
    expect(who.source, UserSource.remembered);
  });

  test('waits for the library before using the remembered person', () async {
    final watch = Stopwatch()..start();

    await resolve(library: () => null, memory: FakeMemory(session));

    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(55));
  });

  test('prefers the library when it gets its session while waiting', () async {
    var asked = 0;

    final who = await resolve(
      library: () => ++asked > 3 ? fromLibrary : null,
      memory: FakeMemory(session),
    );

    expect(who!.user, fromLibrary);
    expect(who.source, UserSource.library);
  });

  test('a failure reading what the phone remembers means nobody, not a crash', () async {
    final who = await resolve(
      library: () => null,
      memory: FakeMemory(session, failure: StateError('no preferences')),
    );

    expect(who, isNull);
  });
}
