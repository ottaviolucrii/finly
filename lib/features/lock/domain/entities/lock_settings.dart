import 'package:equatable/equatable.dart';

/// Seconds without use (or in the background) before the app locks, from
/// "immediately" to 15 minutes (SRS FR-A07). The database accepts 0 to 900.
const List<int> lockTimeoutOptions = [0, 60, 120, 300, 900];

/// The default is 2 minutes (SRS FR-A07).
const int defaultLockTimeoutSeconds = 120;

class LockSettings extends Equatable {
  final int timeoutSeconds;

  /// Ask for the fingerprint or face first, when the phone has one.
  final bool biometricEnabled;

  const LockSettings({
    this.timeoutSeconds = defaultLockTimeoutSeconds,
    this.biometricEnabled = false,
  });

  Duration get timeout => Duration(seconds: timeoutSeconds);

  /// Locks every time the app goes to the background.
  bool get locksImmediately => timeoutSeconds == 0;

  LockSettings copyWith({int? timeoutSeconds, bool? biometricEnabled}) {
    return LockSettings(
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }

  @override
  List<Object?> get props => [timeoutSeconds, biometricEnabled];
}