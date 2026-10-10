import 'package:finly/core/offline/offline_probe.dart';
import 'package:finly/core/offline/offline_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late OfflineStatus status;
  late int asked;
  late bool answers;
  late Object? error;

  setUp(() {
    status = OfflineStatus();
    asked = 0;
    answers = false;
    error = null;
  });

  OfflineProbe build({Duration interval = const Duration(milliseconds: 20)}) {
    final probe = OfflineProbe(
      status: status,
      interval: interval,
      reachable: () async {
        asked++;
        final failure = error;
        if (failure != null) throw failure;
        return answers;
      },
    );
    addTearDown(probe.dispose);
    return probe;
  }

  group('checkNow', () {
    test('does not ask when the app is not offline', () async {
      final probe = build();

      await probe.checkNow();

      expect(asked, 0);
    });

    test('says the internet is back when the server answers', () async {
      final probe = build();
      status.markOffline();
      answers = true;

      await probe.checkNow();

      expect(status.isOffline, isFalse);
      expect(status.isBackOnline, isTrue);
    });

    test('stays offline when the server does not answer', () async {
      final probe = build();
      status.markOffline();

      await probe.checkNow();

      expect(status.isOffline, isTrue);
      expect(asked, 1);
    });

    test('a failure of the check means still offline, not a crash', () async {
      final probe = build();
      status.markOffline();
      error = Exception('no route');

      await probe.checkNow();

      expect(status.isOffline, isTrue);
    });

    test('does not ask twice at the same time', () async {
      final probe = build();
      status.markOffline();

      await Future.wait([probe.checkNow(), probe.checkNow(), probe.checkNow()]);

      expect(asked, 1);
    });
  });

  group('while offline', () {
    test('asks now and then', () async {
      build();

      status.markOffline();
      await Future<void>.delayed(const Duration(milliseconds: 130));

      expect(asked, greaterThanOrEqualTo(3));
    });

    test('stops asking when the internet is back', () async {
      build();
      status.markOffline();
      answers = true;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(status.isOffline, isFalse);

      final before = asked;
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(asked, before);
    });

    test('does not ask at all while online', () async {
      build();

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(asked, 0);
    });

    test('stops when it is let go', () async {
      final probe = build();
      status.markOffline();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      probe.dispose();
      final before = asked;
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(asked, before);
    });

    test('starts by itself when created while already offline', () async {
      status.markOffline();

      build();
      await Future<void>.delayed(const Duration(milliseconds: 70));

      expect(asked, greaterThanOrEqualTo(1));
    });
  });
}
