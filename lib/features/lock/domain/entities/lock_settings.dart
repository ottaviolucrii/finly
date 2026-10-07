import 'package:equatable/equatable.dart';

/// Seconds without use (or in the background) before the app locks, from
/// "immediately" to 15 minutes (SRS FR-A07). The database accepts 0 to 900.
const List<int> lockTimeoutOptions = [0, 60, 120, 300, 900];

/// The default is 2 minutes (SRS FR-A07).
const int defaultLockTimeoutSeconds = 120;

/// What the user must do to change the active workspace (SRS FR-W04). The
/// names are the values of the `switch_protection` column.
enum SwitchProtection {
  /// A sheet names both workspaces and asks for a tap on "confirm".
  confirm('confirm'),

  /// The phone's fingerprint, face or PIN, with the account password as a
  /// fallback.
  biometric('biometric'),

  /// The account password, checked again.
  password('password');

  final String dbValue;

  const SwitchProtection(this.dbValue);

  /// An unknown or missing value is the safe default, "confirm".
  static SwitchProtection fromDb(String? value) {
    for (final level in SwitchProtection.values) {
      if (level.dbValue == value) return level;
    }
    return SwitchProtection.confirm;
  }
}

class LockSettings extends Equatable {
  final int timeoutSeconds;

  /// Ask for the fingerprint or face first, when the phone has one.
  final bool biometricEnabled;

  /// What it takes to switch workspace.
  final SwitchProtection switchProtection;

  const LockSettings({
    this.timeoutSeconds = defaultLockTimeoutSeconds,
    this.biometricEnabled = false,
    this.switchProtection = SwitchProtection.confirm,
  });

  Duration get timeout => Duration(seconds: timeoutSeconds);

  /// Locks every time the app goes to the background.
  bool get locksImmediately => timeoutSeconds == 0;

  LockSettings copyWith({
    int? timeoutSeconds,
    bool? biometricEnabled,
    SwitchProtection? switchProtection,
  }) {
    return LockSettings(
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      switchProtection: switchProtection ?? this.switchProtection,
    );
  }

  @override
  List<Object?> get props => [timeoutSeconds, biometricEnabled, switchProtection];
}
