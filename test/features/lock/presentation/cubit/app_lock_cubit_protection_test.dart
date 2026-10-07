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

  Future<AppLockCubit> signedInCubit() async {
    final cubit = AppLockCubit(
      getSettings: getSettings,
      saveSettings: saveSettings,
      verifyPassword: verifyPassword,
      device: device,
      clock: () => now,
    );
    addTearDown(cubit.close);
    await cubit.onSignedIn();
    return cubit;
  }

  group('setSwitchProtection', () {
    test('saves the password level without asking the phone', () async {
      final cubit = await signedInCubit();

      await cubit.setSwitchProtection(SwitchProtection.password);

      expect(cubit.state.settings.switchProtection, SwitchProtection.password);
      verify(() => saveSettings(const LockSettings(switchProtection: SwitchProtection.password))).called(1);
      verifyNever(() => device.authenticate(reason: any(named: 'reason')));
    });

    test('going back to confirm just saves', () async {
      when(() => getSettings(any())).thenAnswer(
        (_) async => const Right<Failure, LockSettings>(
          LockSettings(switchProtection: SwitchProtection.password),
        ),
      );
      final cubit = await signedInCubit();

      await cubit.setSwitchProtection(SwitchProtection.confirm);

      expect(cubit.state.settings.switchProtection, SwitchProtection.confirm);
      verify(() => saveSettings(const LockSettings())).called(1);
    });

    test('choosing the level it already has does nothing', () async {
      final cubit = await signedInCubit();

      await cubit.setSwitchProtection(SwitchProtection.confirm);

      verifyNever(() => saveSettings(any()));
    });

    test('the biometric level asks the phone first, then saves', () async {
      final cubit = await signedInCubit();

      await cubit.setSwitchProtection(SwitchProtection.biometric);

      verify(() => device.authenticate(reason: any(named: 'reason'))).called(1);
      expect(cubit.state.settings.switchProtection, SwitchProtection.biometric);
      verify(() => saveSettings(const LockSettings(switchProtection: SwitchProtection.biometric))).called(1);
    });

    test('the biometric level is refused on a phone with no biometrics', () async {
      when(() => device.isSupported()).thenAnswer((_) async => false);
      final cubit = await signedInCubit();

      await cubit.setSwitchProtection(SwitchProtection.biometric);

      expect(cubit.state.error, LockError.biometricUnavailable);
      expect(cubit.state.settings.switchProtection, SwitchProtection.confirm);
      verifyNever(() => saveSettings(any()));
    });

    test('the biometric level is not saved when the prompt is not confirmed', () async {
      when(() => device.authenticate(reason: any(named: 'reason')))
          .thenAnswer((_) async => false);
      final cubit = await signedInCubit();

      await cubit.setSwitchProtection(SwitchProtection.biometric);

      expect(cubit.state.error, LockError.biometricNotConfirmed);
      expect(cubit.state.settings.switchProtection, SwitchProtection.confirm);
      verifyNever(() => saveSettings(any()));
    });

    test('a failed save goes back to the old level and says so', () async {
      when(() => saveSettings(any())).thenAnswer(
        (_) async => const Left<Failure, void>(NetworkFailure('network_error')),
      );
      final cubit = await signedInCubit();

      await cubit.setSwitchProtection(SwitchProtection.password);

      expect(cubit.state.settings.switchProtection, SwitchProtection.confirm);
      expect(cubit.state.error, LockError.saveFailed);
    });
  });

  group('checkPassword', () {
    test('the right password is accepted', () async {
      final cubit = await signedInCubit();

      final result = await cubit.checkPassword('segredo123');

      expect(result.ok, isTrue);
      verify(() => verifyPassword('segredo123')).called(1);
    });

    test('a wrong password is refused and the tries left are counted', () async {
      when(() => verifyPassword(any())).thenAnswer((_) async => wrongPassword);
      final cubit = await signedInCubit();

      final result = await cubit.checkPassword('errada');

      expect(result.ok, isFalse);
      expect(result.error, LockError.wrongPassword);
      expect(result.attemptsLeft, 4);
    });

    test('the fifth wrong password blocks for five minutes', () async {
      when(() => verifyPassword(any())).thenAnswer((_) async => wrongPassword);
      final cubit = await signedInCubit();

      for (var i = 0; i < 4; i++) {
        await cubit.checkPassword('errada');
      }
      final fifth = await cubit.checkPassword('errada');

      expect(fifth.error, LockError.blocked);
      expect(fifth.attemptsLeft, 0);
      expect(fifth.blockedUntil, now.add(const Duration(minutes: 5)));
    });

    test('while blocked, the password is not even sent', () async {
      when(() => verifyPassword(any())).thenAnswer((_) async => wrongPassword);
      final cubit = await signedInCubit();
      for (var i = 0; i < 5; i++) {
        await cubit.checkPassword('errada');
      }

      final result = await cubit.checkPassword('segredo123');

      expect(result.error, LockError.blocked);
      verify(() => verifyPassword(any())).called(5);
    });

    test('after five minutes the right password works again', () async {
      when(() => verifyPassword(any())).thenAnswer((_) async => wrongPassword);
      final cubit = await signedInCubit();
      for (var i = 0; i < 5; i++) {
        await cubit.checkPassword('errada');
      }

      now = now.add(const Duration(minutes: 5));
      when(() => verifyPassword(any())).thenAnswer((_) async => rightPassword);
      final result = await cubit.checkPassword('segredo123');

      expect(result.ok, isTrue);
    });

    test('a success clears the wrong tries', () async {
      when(() => verifyPassword(any())).thenAnswer((_) async => wrongPassword);
      final cubit = await signedInCubit();
      await cubit.checkPassword('errada');
      await cubit.checkPassword('errada');

      when(() => verifyPassword(any())).thenAnswer((_) async => rightPassword);
      await cubit.checkPassword('segredo123');
      when(() => verifyPassword(any())).thenAnswer((_) async => wrongPassword);
      final next = await cubit.checkPassword('errada');

      expect(next.attemptsLeft, AttemptLimiter.maxFailures - 1);
    });

    test('a connection problem is not counted as a wrong password', () async {
      when(() => verifyPassword(any())).thenAnswer(
        (_) async => const Left<Failure, void>(NetworkFailure('network_error')),
      );
      final cubit = await signedInCubit();

      for (var i = 0; i < 8; i++) {
        final result = await cubit.checkPassword('segredo123');
        expect(result.error, LockError.network);
        expect(result.blockedUntil, isNull);
      }

      when(() => verifyPassword(any())).thenAnswer((_) async => wrongPassword);
      final wrong = await cubit.checkPassword('errada');
      expect(wrong.attemptsLeft, 4);
    });

    test('the lock screen and the workspace switch share the same tries', () async {
      when(() => verifyPassword(any())).thenAnswer((_) async => wrongPassword);
      final cubit = await signedInCubit();
      cubit.lockNow();

      for (var i = 0; i < 3; i++) {
        await cubit.checkPassword('errada'); // the workspace switch
      }
      await cubit.unlockWithPassword('errada'); // the lock screen
      await cubit.unlockWithPassword('errada');

      expect(cubit.state.error, LockError.blocked);
      expect(cubit.state.locked, isTrue);
    });

    test('a server rate limit and other failures are reported on their own', () async {
      final cubit = await signedInCubit();

      when(() => verifyPassword(any())).thenAnswer(
        (_) async => const Left<Failure, void>(AuthFailure('rate_limited')),
      );
      expect((await cubit.checkPassword('x')).error, LockError.rateLimited);

      when(() => verifyPassword(any())).thenAnswer(
        (_) async => const Left<Failure, void>(ServerFailure('unknown_error')),
      );
      expect((await cubit.checkPassword('x')).error, LockError.other);
    });
  });

  group('confirmWithDevice', () {
    test('returns what the phone says', () async {
      final cubit = await signedInCubit();

      expect(await cubit.confirmWithDevice('Confirme'), isTrue);

      when(() => device.authenticate(reason: any(named: 'reason')))
          .thenAnswer((_) async => false);
      expect(await cubit.confirmWithDevice('Confirme'), isFalse);
    });

    test('the phone prompt sending the app away does not lock it', () async {
      when(() => getSettings(any())).thenAnswer(
        (_) async => const Right<Failure, LockSettings>(LockSettings(timeoutSeconds: 0)),
      );
      final cubit = await signedInCubit();
      when(() => device.authenticate(reason: any(named: 'reason'))).thenAnswer((_) async {
        cubit.onBackgrounded();
        now = now.add(const Duration(minutes: 10));
        cubit.onResumed();
        return true;
      });

      await cubit.confirmWithDevice('Confirme');

      expect(cubit.state.locked, isFalse);
    });
  });
}
