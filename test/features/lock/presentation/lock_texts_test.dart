import 'package:finly/features/lock/presentation/cubit/app_lock_state.dart';
import 'package:finly/features/lock/presentation/lock_texts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 6, 12);

  group('lockTimeoutLabel', () {
    test('names every option', () {
      expect(lockTimeoutLabel(0), 'Imediatamente');
      expect(lockTimeoutLabel(60), '1 minuto');
      expect(lockTimeoutLabel(120), '2 minutos');
      expect(lockTimeoutLabel(300), '5 minutos');
      expect(lockTimeoutLabel(900), '15 minutos');
    });
  });

  group('formatCountdown', () {
    test('writes minutes and two-digit seconds', () {
      expect(formatCountdown(const Duration(minutes: 4, seconds: 32)), '4:32');
      expect(formatCountdown(const Duration(minutes: 5)), '5:00');
      expect(formatCountdown(const Duration(seconds: 7)), '0:07');
    });

    test('a part of a second counts as a whole one', () {
      expect(formatCountdown(const Duration(milliseconds: 400)), '0:01');
    });

    test('never goes below zero', () {
      expect(formatCountdown(const Duration(seconds: -5)), '0:00');
      expect(formatCountdown(Duration.zero), '0:00');
    });
  });

  group('lockUnlockError', () {
    test('says nothing when all is well', () {
      expect(lockUnlockError(const AppLockState(), now), isNull);
    });

    test('a wrong password says how many tries are left', () {
      final text = lockUnlockError(
        const AppLockState(error: LockError.wrongPassword, attemptsLeft: 3),
        now,
      );

      expect(text, 'Senha incorreta. Restam 3 tentativas.');
    });

    test('uses the singular for the last try', () {
      final text = lockUnlockError(
        const AppLockState(error: LockError.wrongPassword, attemptsLeft: 1),
        now,
      );

      expect(text, 'Senha incorreta. Resta 1 tentativa.');
    });

    test('a running block shows the countdown', () {
      final text = lockUnlockError(
        AppLockState(
          error: LockError.blocked,
          blockedUntil: now.add(const Duration(minutes: 4, seconds: 30)),
        ),
        now,
      );

      expect(text, contains('Muitas tentativas erradas'));
      expect(text, contains('4:30'));
    });

    test('a block that is over says nothing', () {
      final text = lockUnlockError(
        AppLockState(
          error: LockError.blocked,
          blockedUntil: now.subtract(const Duration(seconds: 1)),
        ),
        now,
      );

      expect(text, isNull);
    });

    test('has a message for the other unlock problems', () {
      for (final error in [
        LockError.rateLimited,
        LockError.network,
        LockError.deviceFailed,
        LockError.other,
      ]) {
        expect(lockUnlockError(AppLockState(error: error), now), isNotNull, reason: '$error');
      }
    });

    test('does not show a settings error on the lock screen', () {
      for (final error in [
        LockError.biometricUnavailable,
        LockError.biometricNotConfirmed,
        LockError.saveFailed,
      ]) {
        expect(lockUnlockError(AppLockState(error: error), now), isNull, reason: '$error');
      }
    });
  });

  group('lockSettingsError', () {
    test('has a message for each settings problem', () {
      expect(lockSettingsError(LockError.biometricUnavailable), isNotNull);
      expect(lockSettingsError(LockError.biometricNotConfirmed), isNotNull);
      expect(lockSettingsError(LockError.saveFailed), isNotNull);
    });

    test('says nothing for the unlock problems', () {
      for (final error in [
        LockError.none,
        LockError.wrongPassword,
        LockError.blocked,
        LockError.rateLimited,
        LockError.network,
        LockError.deviceFailed,
        LockError.other,
      ]) {
        expect(lockSettingsError(error), isNull, reason: '$error');
      }
    });
  });
}