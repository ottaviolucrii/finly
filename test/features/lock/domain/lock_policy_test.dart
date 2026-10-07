import 'package:finly/features/lock/domain/entities/lock_settings.dart';
import 'package:finly/features/lock/domain/lock_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 6, 12);
  const twoMinutes = LockSettings();
  const immediately = LockSettings(timeoutSeconds: 0);

  group('shouldLockAfterBackground', () {
    test('coming back before the time does not lock', () {
      expect(
        shouldLockAfterBackground(twoMinutes, start, start.add(const Duration(seconds: 119))),
        isFalse,
      );
    });

    test('coming back exactly at the time locks', () {
      expect(
        shouldLockAfterBackground(twoMinutes, start, start.add(const Duration(seconds: 120))),
        isTrue,
      );
    });

    test('coming back much later locks', () {
      expect(
        shouldLockAfterBackground(twoMinutes, start, start.add(const Duration(hours: 3))),
        isTrue,
      );
    });

    test('with "immediately", any return locks, even right away', () {
      expect(shouldLockAfterBackground(immediately, start, start), isTrue);
    });

    test('uses the time of the settings', () {
      const fifteen = LockSettings(timeoutSeconds: 900);

      expect(
        shouldLockAfterBackground(fifteen, start, start.add(const Duration(minutes: 14))),
        isFalse,
      );
      expect(
        shouldLockAfterBackground(fifteen, start, start.add(const Duration(minutes: 15))),
        isTrue,
      );
    });
  });

  group('shouldLockForIdle', () {
    test('a short pause does not lock', () {
      expect(
        shouldLockForIdle(twoMinutes, start, start.add(const Duration(seconds: 90))),
        isFalse,
      );
    });

    test('leaving it alone for the whole time locks', () {
      expect(
        shouldLockForIdle(twoMinutes, start, start.add(const Duration(seconds: 120))),
        isTrue,
      );
    });

    test('"immediately" never locks a screen that is in use', () {
      expect(
        shouldLockForIdle(immediately, start, start.add(const Duration(hours: 1))),
        isFalse,
      );
    });
  });

  group('LockSettings', () {
    test('the default is 2 minutes with no biometrics', () {
      const settings = LockSettings();

      expect(settings.timeoutSeconds, 120);
      expect(settings.biometricEnabled, isFalse);
      expect(settings.timeout, const Duration(minutes: 2));
      expect(settings.locksImmediately, isFalse);
    });

    test('zero seconds means "immediately"', () {
      expect(const LockSettings(timeoutSeconds: 0).locksImmediately, isTrue);
    });

    test('copyWith changes one thing and keeps the other', () {
      const settings = LockSettings(timeoutSeconds: 300, biometricEnabled: true);

      expect(settings.copyWith(timeoutSeconds: 60).biometricEnabled, isTrue);
      expect(settings.copyWith(biometricEnabled: false).timeoutSeconds, 300);
    });

    test('the options run from immediately to 15 minutes and include the default', () {
      expect(lockTimeoutOptions.first, 0);
      expect(lockTimeoutOptions.last, 900);
      expect(lockTimeoutOptions, contains(defaultLockTimeoutSeconds));
      expect([...lockTimeoutOptions]..sort(), lockTimeoutOptions);
    });
  });
}