import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/security/device_authenticator.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/lock/domain/attempt_limiter.dart';
import 'package:finly/features/lock/domain/entities/lock_settings.dart';
import 'package:finly/features/lock/domain/usecases/get_lock_settings_use_case.dart';
import 'package:finly/features/lock/domain/usecases/save_lock_settings_use_case.dart';
import 'package:finly/features/lock/domain/usecases/verify_password_use_case.dart';
import 'package:finly/features/lock/presentation/cubit/app_lock_cubit.dart';
import 'package:finly/features/lock/presentation/cubit/app_lock_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetSettings extends Mock implements GetLockSettingsUseCase {}

class MockSaveSettings extends Mock implements SaveLockSettingsUseCase {}

class MockVerifyPassword extends Mock implements VerifyPasswordUseCase {}

class MockDevice extends Mock implements DeviceAuthenticator {}

void main() {
  late MockGetSettings getSettings;
  late MockSaveSettings saveSettings;
  late MockVerifyPassword verifyPassword;
  late MockDevice device;
  late DateTime now;

  const wrongPassword = Left<Failure, void>(AuthFailure('invalid_credentials'));
  const rightPassword = Right<Failure, void>(null);

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const LockSettings());
  });

  setUp(() {
    now = DateTime(2026, 10, 6, 12);
    getSettings = MockGetSettings();
    saveSettings = MockSaveSettings();
    verifyPassword = MockVerifyPassword();
    device = MockDevice();

    when(() => getSettings(any())).thenAnswer(
      (_) async => const Right<Failure, LockSettings>(LockSettings()),
    );
    when(() => saveSettings(any()))
        .thenAnswer((_) async => const Right<Failure, void>(null));
    when(() => verifyPassword(any())).thenAnswer((_) async => rightPassword);
    when(() => device.isSupported()).thenAnswer((_) async => true);
    when(() => device.authenticate(reason: any(named: 'reason')))
        .thenAnswer((_) async => true);
  });

  AppLockCubit build() {
    final cubit = AppLockCubit(
      getSettings: getSettings,
      saveSettings: saveSettings,
      verifyPassword: verifyPassword,
      device: device,
      clock: () => now,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  /// A user who just signed in: unlocked, with the default settings loaded.
  Future<AppLockCubit> signedInCubit() async {
    final cubit = build();
    await cubit.onSignedIn();
    return cubit;
  }

  /// A saved login found at start: locked, with the settings loaded.
  Future<AppLockCubit> lockedCubit() async {
    final cubit = build();
    await cubit.onSessionRestored();
    return cubit;
  }

  void advance(Duration time) => now = now.add(time);

  group('who is signed in', () {
    test('starts locked and signed out, so no lock screen shows yet', () {
      final cubit = build();

      expect(cubit.state.signedIn, isFalse);
      expect(cubit.state.locked, isTrue);
      expect(cubit.state.showsLock, isFalse);
    });

    test('a restored session stays locked and loads the settings', () async {
      when(() => getSettings(any())).thenAnswer(
        (_) async => const Right<Failure, LockSettings>(
          LockSettings(timeoutSeconds: 300, biometricEnabled: true),
        ),
      );

      final cubit = await lockedCubit();

      expect(cubit.state.signedIn, isTrue);
      expect(cubit.state.showsLock, isTrue);
      expect(cubit.state.settingsReady, isTrue);
      expect(cubit.state.settings.timeoutSeconds, 300);
      expect(cubit.state.settings.biometricEnabled, isTrue);
      expect(cubit.state.deviceSupported, isTrue);
    });

    test('typing the password to sign in does not lock the user out', () async {
      final cubit = build();

      cubit.unlockForSignIn();
      await cubit.onSignedIn();

      expect(cubit.state.signedIn, isTrue);
      expect(cubit.state.locked, isFalse);
      expect(cubit.state.showsLock, isFalse);
    });

    test('signing out clears everything and leaves nothing locked', () async {
      final cubit = await lockedCubit();

      cubit.onSignedOut();

      expect(cubit.state.signedIn, isFalse);
      expect(cubit.state.locked, isFalse);
      expect(cubit.state.settingsReady, isFalse);
      expect(cubit.state.settings, const LockSettings());
    });

    test('settings that fail to load leave the defaults in place', () async {
      when(() => getSettings(any())).thenAnswer(
        (_) async => const Left<Failure, LockSettings>(NetworkFailure('network_error')),
      );

      final cubit = await lockedCubit();

      expect(cubit.state.settingsReady, isTrue);
      expect(cubit.state.settings, const LockSettings());
    });

    test('a phone with no biometrics or screen lock is noted', () async {
      when(() => device.isSupported()).thenAnswer((_) async => false);

      final cubit = await lockedCubit();

      expect(cubit.state.deviceSupported, isFalse);
    });
  });

  group('locking after the background', () {
    test('coming back before the time does not lock', () async {
      final cubit = await signedInCubit();

      cubit.onBackgrounded();
      advance(const Duration(seconds: 119));
      cubit.onResumed();

      expect(cubit.state.locked, isFalse);
    });

    test('coming back after the time locks', () async {
      final cubit = await signedInCubit();

      cubit.onBackgrounded();
      advance(const Duration(seconds: 120));
      cubit.onResumed();

      expect(cubit.state.locked, isTrue);
      expect(cubit.state.showsLock, isTrue);
    });

    test('with "immediately", any return locks', () async {
      when(() => getSettings(any())).thenAnswer(
        (_) async => const Right<Failure, LockSettings>(LockSettings(timeoutSeconds: 0)),
      );
      final cubit = await signedInCubit();

      cubit.onBackgrounded();
      cubit.onResumed();

      expect(cubit.state.locked, isTrue);
    });

    test('nothing locks when nobody is signed in', () {
      final cubit = build();

      cubit.onBackgrounded();
      advance(const Duration(hours: 1));
      cubit.onResumed();

      expect(cubit.state.showsLock, isFalse);
    });

    test('the first time in the background counts, not a later one', () async {
      final cubit = await signedInCubit();

      cubit.onBackgrounded();
      advance(const Duration(seconds: 100));
      cubit.onBackgrounded();
      advance(const Duration(seconds: 25));
      cubit.onResumed();

      expect(cubit.state.locked, isTrue);
    });

    test('a short return restarts the idle count', () async {
      final cubit = await signedInCubit();

      cubit.onBackgrounded();
      advance(const Duration(seconds: 60));
      cubit.onResumed();
      advance(const Duration(seconds: 100));
      cubit.checkIdle();

      expect(cubit.state.locked, isFalse);
    });
  });

  group('locking when left alone', () {
    test('locks after the time without a touch', () async {
      final cubit = await signedInCubit();

      advance(const Duration(seconds: 120));
      cubit.checkIdle();

      expect(cubit.state.locked, isTrue);
    });

    test('does not lock before the time', () async {
      final cubit = await signedInCubit();

      advance(const Duration(seconds: 119));
      cubit.checkIdle();

      expect(cubit.state.locked, isFalse);
    });

    test('a touch restarts the count', () async {
      final cubit = await signedInCubit();

      advance(const Duration(seconds: 100));
      cubit.onUserActivity();
      advance(const Duration(seconds: 100));
      cubit.checkIdle();
      expect(cubit.state.locked, isFalse);

      advance(const Duration(seconds: 25));
      cubit.checkIdle();
      expect(cubit.state.locked, isTrue);
    });

    test('"immediately" never locks a screen in use', () async {
      when(() => getSettings(any())).thenAnswer(
        (_) async => const Right<Failure, LockSettings>(LockSettings(timeoutSeconds: 0)),
      );
      final cubit = await signedInCubit();

      advance(const Duration(hours: 1));
      cubit.checkIdle();

      expect(cubit.state.locked, isFalse);
    });

    test('lockNow locks at once', () async {
      final cubit = await signedInCubit();

      cubit.lockNow();

      expect(cubit.state.locked, isTrue);
    });

    test('lockNow does nothing when nobody is signed in', () {
      final cubit = build();
      cubit.unlockForSignIn();

      cubit.lockNow();

      expect(cubit.state.locked, isFalse);
    });
  });

  group('unlocking with the phone', () {
    test('a confirmed prompt unlocks', () async {
      final cubit = await lockedCubit();

      await cubit.unlockWithDevice();

      expect(cubit.state.locked, isFalse);
      expect(cubit.state.working, isFalse);
      expect(cubit.state.error, LockError.none);
    });

    test('a cancelled prompt keeps it locked and says so', () async {
      when(() => device.authenticate(reason: any(named: 'reason')))
          .thenAnswer((_) async => false);
      final cubit = await lockedCubit();

      await cubit.unlockWithDevice();

      expect(cubit.state.locked, isTrue);
      expect(cubit.state.error, LockError.deviceFailed);
      expect(cubit.state.working, isFalse);
    });

    test('a cancelled prompt does not count as a wrong password', () async {
      when(() => device.authenticate(reason: any(named: 'reason')))
          .thenAnswer((_) async => false);
      final cubit = await lockedCubit();

      for (var i = 0; i < 6; i++) {
        await cubit.unlockWithDevice();
      }

      expect(cubit.state.blockedUntil, isNull);
      expect(cubit.state.attemptsLeft, AttemptLimiter.maxFailures);
    });

    test('does nothing when it is not locked', () async {
      final cubit = await signedInCubit();

      await cubit.unlockWithDevice();

      verifyNever(() => device.authenticate(reason: any(named: 'reason')));
    });
  });

  group('unlocking with the password', () {
    test('the right password unlocks', () async {
      final cubit = await lockedCubit();

      await cubit.unlockWithPassword('segredo123');

      expect(cubit.state.locked, isFalse);
      expect(cubit.state.error, LockError.none);
      verify(() => verifyPassword('segredo123')).called(1);
    });

    test('a wrong password keeps it locked and counts the tries left', () async {
      when(() => verifyPassword(any())).thenAnswer((_) async => wrongPassword);
      final cubit = await lockedCubit();

      await cubit.unlockWithPassword('errada');

      expect(cubit.state.locked, isTrue);
      expect(cubit.state.error, LockError.wrongPassword);
      expect(cubit.state.attemptsLeft, 4);
      expect(cubit.state.working, isFalse);
    });

    test('the fifth wrong password blocks for five minutes', () async {
      when(() => verifyPassword(any())).thenAnswer((_) async => wrongPassword);
      final cubit = await lockedCubit();

      for (var i = 0; i < 4; i++) {
        await cubit.unlockWithPassword('errada');
      }
      expect(cubit.state.attemptsLeft, 1);
      expect(cubit.state.error, LockError.wrongPassword);

      await cubit.unlockWithPassword('errada');

      expect(cubit.state.error, LockError.blocked);
      expect(cubit.state.attemptsLeft, 0);
      expect(cubit.state.blockedUntil, now.add(const Duration(minutes: 5)));
    });

    test('while blocked, the password is not even checked', () async {
      when(() => verifyPassword(any())).thenAnswer((_) async => wrongPassword);
      final cubit = await lockedCubit();
      for (var i = 0; i < 5; i++) {
        await cubit.unlockWithPassword('errada');
      }

      await cubit.unlockWithPassword('segredo123');

      verify(() => verifyPassword(any())).called(5);
      expect(cubit.state.locked, isTrue);
      expect(cubit.state.error, LockError.blocked);
    });

    test('after five minutes the right password works again', () async {
      when(() => verifyPassword(any())).thenAnswer((_) async => wrongPassword);
      final cubit = await lockedCubit();
      for (var i = 0; i < 5; i++) {
        await cubit.unlockWithPassword('errada');
      }

      advance(const Duration(minutes: 5));
      when(() => verifyPassword(any())).thenAnswer((_) async => rightPassword);
      await cubit.unlockWithPassword('segredo123');

      expect(cubit.state.locked, isFalse);
      expect(cubit.state.blockedUntil, isNull);
      expect(cubit.state.attemptsLeft, AttemptLimiter.maxFailures);
    });

    test('a success clears the wrong tries', () async {
      when(() => verifyPassword(any())).thenAnswer((_) async => wrongPassword);
      final cubit = await lockedCubit();
      await cubit.unlockWithPassword('errada');
      await cubit.unlockWithPassword('errada');
      expect(cubit.state.attemptsLeft, 3);

      when(() => verifyPassword(any())).thenAnswer((_) async => rightPassword);
      await cubit.unlockWithPassword('segredo123');

      expect(cubit.state.attemptsLeft, AttemptLimiter.maxFailures);
    });

    test('a connection problem is not counted as a wrong password', () async {
      when(() => verifyPassword(any())).thenAnswer(
        (_) async => const Left<Failure, void>(NetworkFailure('network_error')),
      );
      final cubit = await lockedCubit();

      for (var i = 0; i < 8; i++) {
        await cubit.unlockWithPassword('segredo123');
      }
      expect(cubit.state.error, LockError.network);
      expect(cubit.state.blockedUntil, isNull);

      when(() => verifyPassword(any())).thenAnswer((_) async => wrongPassword);
      await cubit.unlockWithPassword('errada');
      expect(cubit.state.attemptsLeft, 4);
    });

    test('the server rate limit is reported on its own', () async {
      when(() => verifyPassword(any())).thenAnswer(
        (_) async => const Left<Failure, void>(AuthFailure('rate_limited')),
      );
      final cubit = await lockedCubit();

      await cubit.unlockWithPassword('segredo123');

      expect(cubit.state.error, LockError.rateLimited);
    });

    test('any other failure is a generic error', () async {
      when(() => verifyPassword(any())).thenAnswer(
        (_) async => const Left<Failure, void>(ServerFailure('unknown_error')),
      );
      final cubit = await lockedCubit();

      await cubit.unlockWithPassword('segredo123');

      expect(cubit.state.error, LockError.other);
      expect(cubit.state.locked, isTrue);
    });
  });

  group('settings', () {
    test('setTimeout saves the new time and shows it', () async {
      final cubit = await signedInCubit();

      await cubit.setTimeout(300);

      expect(cubit.state.settings.timeoutSeconds, 300);
      verify(() => saveSettings(const LockSettings(timeoutSeconds: 300))).called(1);
    });

    test('a time that is not an option is ignored', () async {
      final cubit = await signedInCubit();

      await cubit.setTimeout(45);

      expect(cubit.state.settings.timeoutSeconds, 120);
      verifyNever(() => saveSettings(any()));
    });

    test('a failed save goes back to the old time and says so', () async {
      when(() => saveSettings(any())).thenAnswer(
        (_) async => const Left<Failure, void>(NetworkFailure('network_error')),
      );
      final cubit = await signedInCubit();

      await cubit.setTimeout(300);

      expect(cubit.state.settings.timeoutSeconds, 120);
      expect(cubit.state.error, LockError.saveFailed);
    });

    test('turning biometrics on asks the phone first, then saves', () async {
      final cubit = await signedInCubit();

      await cubit.setBiometric(true);

      verify(() => device.authenticate(reason: any(named: 'reason'))).called(1);
      verify(() => saveSettings(const LockSettings(biometricEnabled: true))).called(1);
      expect(cubit.state.settings.biometricEnabled, isTrue);
    });

    test('biometrics stay off when the phone has none', () async {
      when(() => device.isSupported()).thenAnswer((_) async => false);
      final cubit = await signedInCubit();

      await cubit.setBiometric(true);

      expect(cubit.state.error, LockError.biometricUnavailable);
      expect(cubit.state.settings.biometricEnabled, isFalse);
      verifyNever(() => saveSettings(any()));
    });

    test('biometrics stay off when the prompt is not confirmed', () async {
      when(() => device.authenticate(reason: any(named: 'reason')))
          .thenAnswer((_) async => false);
      final cubit = await signedInCubit();

      await cubit.setBiometric(true);

      expect(cubit.state.error, LockError.biometricNotConfirmed);
      expect(cubit.state.settings.biometricEnabled, isFalse);
      verifyNever(() => saveSettings(any()));
    });

    test('turning biometrics off just saves, with no prompt', () async {
      when(() => getSettings(any())).thenAnswer(
        (_) async => const Right<Failure, LockSettings>(
          LockSettings(biometricEnabled: true),
        ),
      );
      final cubit = await signedInCubit();

      await cubit.setBiometric(false);

      verifyNever(() => device.authenticate(reason: any(named: 'reason')));
      verify(() => saveSettings(const LockSettings())).called(1);
      expect(cubit.state.settings.biometricEnabled, isFalse);
    });

    test('the prompt of the phone sending the app away does not lock it', () async {
      when(() => getSettings(any())).thenAnswer(
        (_) async => const Right<Failure, LockSettings>(LockSettings(timeoutSeconds: 0)),
      );
      final cubit = await signedInCubit();
      when(() => device.authenticate(reason: any(named: 'reason'))).thenAnswer((_) async {
        // The system prompt takes the app to the background for a moment.
        cubit.onBackgrounded();
        advance(const Duration(minutes: 10));
        cubit.onResumed();
        return true;
      });

      await cubit.setBiometric(true);

      expect(cubit.state.locked, isFalse);
      expect(cubit.state.settings.biometricEnabled, isTrue);
    });
  });
}