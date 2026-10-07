import 'package:finly/features/lock/domain/entities/lock_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SwitchProtection', () {
    test('uses the values of the database enum', () {
      expect(SwitchProtection.confirm.dbValue, 'confirm');
      expect(SwitchProtection.biometric.dbValue, 'biometric');
      expect(SwitchProtection.password.dbValue, 'password');
    });

    test('reads every value back from the database', () {
      for (final level in SwitchProtection.values) {
        expect(SwitchProtection.fromDb(level.dbValue), level);
      }
    });

    test('an unknown or missing value is the safe default, confirm', () {
      expect(SwitchProtection.fromDb(null), SwitchProtection.confirm);
      expect(SwitchProtection.fromDb(''), SwitchProtection.confirm);
      expect(SwitchProtection.fromDb('pin'), SwitchProtection.confirm);
    });
  });

  group('LockSettings with a switch protection', () {
    test('the default is confirm', () {
      expect(const LockSettings().switchProtection, SwitchProtection.confirm);
    });

    test('copyWith changes the level and keeps the rest', () {
      const settings = LockSettings(timeoutSeconds: 300, biometricEnabled: true);

      final changed = settings.copyWith(switchProtection: SwitchProtection.password);

      expect(changed.switchProtection, SwitchProtection.password);
      expect(changed.timeoutSeconds, 300);
      expect(changed.biometricEnabled, isTrue);
    });

    test('copyWith of something else keeps the level', () {
      const settings = LockSettings(switchProtection: SwitchProtection.biometric);

      expect(settings.copyWith(timeoutSeconds: 60).switchProtection, SwitchProtection.biometric);
    });

    test('settings with different levels are not equal', () {
      expect(
        const LockSettings(switchProtection: SwitchProtection.password),
        isNot(const LockSettings()),
      );
    });
  });
}
