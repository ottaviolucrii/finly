import 'package:finly/features/lock/data/datasources/lock_remote_data_source.dart';
import 'package:finly/features/lock/data/models/lock_settings_model.dart';
import 'package:finly/features/lock/data/repositories/lock_repository_impl.dart';
import 'package:finly/features/lock/domain/entities/lock_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRemote extends Mock implements LockRemoteDataSource {}

void main() {
  group('LockSettingsModel and the switch protection', () {
    test('reads the level from the database', () {
      final model = LockSettingsModel.fromMap({
        'lock_timeout_seconds': 120,
        'biometric_enabled': false,
        'switch_protection': 'password',
      });

      expect(model.switchProtection, SwitchProtection.password);
    });

    test('a row without the column falls back to confirm', () {
      final model = LockSettingsModel.fromMap({
        'lock_timeout_seconds': 120,
        'biometric_enabled': false,
      });

      expect(model.switchProtection, SwitchProtection.confirm);
    });

    test('an unknown value falls back to confirm', () {
      final model = LockSettingsModel.fromMap({
        'lock_timeout_seconds': 120,
        'biometric_enabled': false,
        'switch_protection': 'something-new',
      });

      expect(model.switchProtection, SwitchProtection.confirm);
    });
  });

  group('LockRepositoryImpl and the switch protection', () {
    setUpAll(() => registerFallbackValue(const LockSettings()));

    test('saves the level together with the other settings', () async {
      final remote = MockRemote();
      when(() => remote.saveSettings(any())).thenAnswer((_) async {});
      const settings = LockSettings(
        timeoutSeconds: 300,
        biometricEnabled: true,
        switchProtection: SwitchProtection.biometric,
      );

      final result = await LockRepositoryImpl(remote).saveSettings(settings);

      expect(result.isRight(), isTrue);
      verify(() => remote.saveSettings(settings)).called(1);
    });

    test('returns the level the data source read', () async {
      final remote = MockRemote();
      when(() => remote.getSettings()).thenAnswer(
        (_) async => const LockSettingsModel(switchProtection: SwitchProtection.password),
      );

      final result = await LockRepositoryImpl(remote).getSettings();

      result.fold(
        (failure) => fail('expected settings, got $failure'),
        (settings) => expect(settings.switchProtection, SwitchProtection.password),
      );
    });
  });
}
