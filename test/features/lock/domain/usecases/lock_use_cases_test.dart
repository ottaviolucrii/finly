import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/lock/domain/entities/lock_settings.dart';
import 'package:finly/features/lock/domain/repositories/lock_repository.dart';
import 'package:finly/features/lock/domain/usecases/get_lock_settings_use_case.dart';
import 'package:finly/features/lock/domain/usecases/save_lock_settings_use_case.dart';
import 'package:finly/features/lock/domain/usecases/verify_password_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLockRepository extends Mock implements LockRepository {}

void main() {
  late MockLockRepository repository;

  setUpAll(() => registerFallbackValue(const LockSettings()));

  setUp(() => repository = MockLockRepository());

  group('GetLockSettingsUseCase', () {
    test('returns the settings of the repository', () async {
      const settings = LockSettings(timeoutSeconds: 300, biometricEnabled: true);
      when(() => repository.getSettings()).thenAnswer(
        (_) async => const Right<Failure, LockSettings>(settings),
      );

      final result = await GetLockSettingsUseCase(repository)(const NoParams());

      expect(result, const Right<Failure, LockSettings>(settings));
    });

    test('passes a failure through unchanged', () async {
      when(() => repository.getSettings()).thenAnswer(
        (_) async => const Left<Failure, LockSettings>(NetworkFailure('network_error')),
      );

      final result = await GetLockSettingsUseCase(repository)(const NoParams());

      expect(
        result,
        const Left<Failure, LockSettings>(NetworkFailure('network_error')),
      );
    });
  });

  group('SaveLockSettingsUseCase', () {
    test('rejects a time the screen does not offer', () async {
      for (final seconds in [-1, 30, 61, 600, 901]) {
        final result = await SaveLockSettingsUseCase(repository)(
          LockSettings(timeoutSeconds: seconds),
        );

        expect(
          result,
          const Left<Failure, void>(ValidationFailure('invalid_timeout')),
          reason: '$seconds',
        );
      }
      verifyNever(() => repository.saveSettings(any()));
    });

    test('accepts every time the screen offers', () async {
      when(() => repository.saveSettings(any()))
          .thenAnswer((_) async => const Right<Failure, void>(null));

      for (final seconds in lockTimeoutOptions) {
        final result = await SaveLockSettingsUseCase(repository)(
          LockSettings(timeoutSeconds: seconds),
        );

        expect(result.isRight(), isTrue, reason: '$seconds');
      }
    });

    test('forwards the settings to the repository', () async {
      const settings = LockSettings(timeoutSeconds: 60, biometricEnabled: true);
      when(() => repository.saveSettings(settings))
          .thenAnswer((_) async => const Right<Failure, void>(null));

      await SaveLockSettingsUseCase(repository)(settings);

      verify(() => repository.saveSettings(settings)).called(1);
    });
  });

  group('VerifyPasswordUseCase', () {
    test('rejects an empty password', () async {
      final result = await VerifyPasswordUseCase(repository)('');

      expect(
        result,
        const Left<Failure, void>(ValidationFailure('password_required')),
      );
      verifyNever(() => repository.verifyPassword(any()));
    });

    test('forwards the password to the repository', () async {
      when(() => repository.verifyPassword('segredo123'))
          .thenAnswer((_) async => const Right<Failure, void>(null));

      final result = await VerifyPasswordUseCase(repository)('segredo123');

      expect(result.isRight(), isTrue);
    });

    test('passes a wrong password failure through unchanged', () async {
      when(() => repository.verifyPassword(any())).thenAnswer(
        (_) async => const Left<Failure, void>(AuthFailure('invalid_credentials')),
      );

      final result = await VerifyPasswordUseCase(repository)('errada');

      expect(
        result,
        const Left<Failure, void>(AuthFailure('invalid_credentials')),
      );
    });
  });
}