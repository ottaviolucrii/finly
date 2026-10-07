import 'package:finly/features/lock/domain/entities/lock_settings.dart';

class LockSettingsModel extends LockSettings {
  const LockSettingsModel({super.timeoutSeconds, super.biometricEnabled});

  /// [map] is a row of `user_settings` with the two lock columns.
  factory LockSettingsModel.fromMap(Map<String, dynamic> map) {
    return LockSettingsModel(
      timeoutSeconds: (map['lock_timeout_seconds'] as num).toInt(),
      biometricEnabled: map['biometric_enabled'] as bool,
    );
  }
}