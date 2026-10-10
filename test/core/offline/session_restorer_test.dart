import 'dart:async';

import 'package:finly/core/offline/remembered_user.dart';
import 'package:finly/core/offline/session_restorer.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeMemory extends SessionMemory {
  String? text;

  FakeMemory(this.text);

  @override
  Future<String?> raw() async => text;
}

void main() {
  late FakeMemory memory;
  late bool session;
  late List<String> recovered;
  late DateTime now;
  Future<void> Function(String raw)? onRecover;

  setUp(() {
    memory = FakeMemory('{"user":{"id":"user-1"}}');
    session = false;
    recovered = [];
    now = DateTime(2026, 10, 9, 12);
    onRecover = null;
  });

  SessionRestorer build({Duration minGap = const Duration(seconds: 5)}) {
    return SessionRestorer(
      memory: memory,
      hasSession: () => session,
      minGap: minGap,
      clock: () => now,
      recover: (raw) async {
        recovered.add(raw);
        final custom = onRecover;
        if (custom != null) {
          await custom(raw);
        } else {
          session = true;
        }
      },
    );
  }

  test('does nothing when the library already has a session', () async {
    session = true;

    expect(await build().restore(), isTrue);
    expect(recovered, isEmpty);
  });

  test('does nothing when no session was saved (the person signed out)', () async {
    memory.text = null;

    expect(await build().restore(), isFalse);
    expect(recovered, isEmpty);
  });

  test('gives the saved session to the library, and says it worked', () async {
    expect(await build().restore(), isTrue);
    expect(recovered, ['{"user":{"id":"user-1"}}']);
  });

  test('says no when the library could not renew it (no internet)', () async {
    onRecover = (_) async => throw StateError('no internet');

    expect(await build().restore(), isFalse);
  });

  test('says no when the library took it but has no session', () async {
    onRecover = (_) async {};

    expect(await build().restore(), isFalse);
  });

  test('does not try again right away', () async {
    onRecover = (_) async => throw StateError('no internet');
    final restorer = build();

    await restorer.restore();
    await restorer.restore();

    expect(recovered, hasLength(1));
  });

  test('tries again once the gap has passed', () async {
    onRecover = (_) async => throw StateError('no internet');
    final restorer = build();
    await restorer.restore();

    now = now.add(const Duration(seconds: 6));
    await restorer.restore();

    expect(recovered, hasLength(2));
  });

  test('does not start a second try while one is going on', () async {
    final gate = Completer<void>();
    onRecover = (_) => gate.future;
    final restorer = build(minGap: Duration.zero);

    final first = restorer.restore();
    final second = await restorer.restore();
    session = true;
    gate.complete();
    await first;

    expect(second, isFalse);
    expect(recovered, hasLength(1));
  });
}
