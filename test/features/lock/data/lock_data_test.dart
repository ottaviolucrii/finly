import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/lock/data/datasources/lock_remote_data_source.dart';
import 'package:finly/features/lock/data/models/lock_settings_model.dart';
import 'package:finly/features/lock/data/repositories/lock_repository_impl.dart';
import 'package:finly/features/lock/domain/entities/lock_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements LockRemoteDataSource {}

void main() {
  group('LockSettingsModel', () {
    test('reads the two lock columns of user_settings', () {
      final model = LockSettingsModel.fromMap({
        'lock_timeout_seconds': 300,
        'biometric_enabled': true,
      });

      expect(model.timeoutSeconds, 300);
      expect(model.biometricEnabled, isTrue);
    });

    test('reads a time that arrives as a double', () {
      final model = LockSettingsModel.fromMap({
        'lock_timeout_seconds': 120.0,
        'biometric_enabled': false,
      });

      expect(model.timeoutSeconds, 120);
    });

    test('the defaults are 2 minutes and no biometrics', () {
      const model = LockSettingsModel();

      expect(model.timeoutSeconds, 120);
      expect(model.biometricEnabled, isFalse);
    });
  });

  group('LockRepositoryImpl', () {
    late MockRemote remote;
    late LockRepositoryImpl repository;

    setUpAll(() => registerFallbackValue(const LockSettings()));

    setUp(() {
      remote = MockRemote();
      repository = LockRepositoryImpl(remote);
    });

    test('getSettings returns the settings from the data source', () async {
      const model = LockSettingsModel(timeoutSeconds: 60, biometricEnabled: true);
      when(() => remote.getSettings()).thenAnswer((_) async => model);

      final result = await repository.getSettings();

      expect(result, const Right<Failure, LockSettings>(model));
    });

    test('saveSettings succeeds', () async {
      when(() => remote.saveSettings(any())).thenAnswer((_) async {});

      final result = await repository.saveSettings(const LockSettings(timeoutSeconds: 60));

      expect(result.isRight(), isTrue);
      verify(() => remote.saveSettings(const LockSettings(timeoutSeconds: 60))).called(1);
    });

    test('verifyPassword succeeds', () async {
      when(() => remote.verifyPassword('segredo123')).thenAnswer((_) async {});

      final result = await repository.verifyPassword('segredo123');

      expect(result.isRight(), isTrue);
    });

    test('a wrong password becomes AuthFailure invalid_credentials', () async {
      when(() => remote.verifyPassword(any()))
          .thenThrow(const AuthException('Invalid login credentials'));

      final result = await repository.verifyPassword('errada');

      expect(
        result,
        const Left<Failure, void>(AuthFailure('invalid_credentials')),
      );
    });

    test('too many tries becomes rate_limited', () async {
      when(() => remote.verifyPassword(any())).thenThrow(
        const AuthException('slow down', code: 'over_request_rate_limit'),
      );

      final result = await repository.verifyPassword('errada');

      expect(result, const Left<Failure, void>(AuthFailure('rate_limited')));
    });

    test('a timeout becomes NetworkFailure', () async {
      when(() => remote.getSettings()).thenThrow(TimeoutException('slow'));

      final result = await repository.getSettings();

      expect(
        result,
        const Left<Failure, LockSettings>(NetworkFailure('network_error')),
      );
    });

    test('an unexpected error becomes a failure instead of escaping', () async {
      when(() => remote.saveSettings(any())).thenThrow(StateError('boom'));

      final result = await repository.saveSettings(const LockSettings());

      expect(result, const Left<Failure, void>(ServerFailure('unknown_error')));
    });
  });
}