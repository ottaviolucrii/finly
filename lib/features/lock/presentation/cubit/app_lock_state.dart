import 'package:equatable/equatable.dart';
import 'package:finly/features/lock/domain/attempt_limiter.dart';
import 'package:finly/features/lock/domain/entities/lock_settings.dart';

/// What went wrong on the lock screen or in the lock settings.
enum LockError {
  none,

  // Lock screen
  wrongPassword,
  blocked,
  rateLimited,
  network,
  deviceFailed,
  other,

  // Settings
  biometricUnavailable,
  biometricNotConfirmed,
  saveFailed,
}

class AppLockState extends Equatable {
  /// Someone is signed in (the lock only means something then).
  final bool signedIn;

  /// The lock screen must be up. The app starts locked.
  final bool locked;

  /// The settings of the user were read (or the read failed and the defaults
  /// apply).
  final bool settingsReady;
  final LockSettings settings;

  /// The phone has a biometric sensor or a screen lock to ask.
  final bool deviceSupported;

  /// An unlock attempt is running.
  final bool working;
  final LockError error;

  /// Wrong passwords left before the block.
  final int attemptsLeft;
  final DateTime? blockedUntil;

  const AppLockState({
    this.signedIn = false,
    this.locked = true,
    this.settingsReady = false,
    this.settings = const LockSettings(),
    this.deviceSupported = false,
    this.working = false,
    this.error = LockError.none,
    this.attemptsLeft = AttemptLimiter.maxFailures,
    this.blockedUntil,
  });

  /// The lock screen is showing.
  bool get showsLock => signedIn && locked;

  AppLockState copyWith({
    bool? signedIn,
    bool? locked,
    bool? settingsReady,
    LockSettings? settings,
    bool? deviceSupported,
    bool? working,
    LockError? error,
    int? attemptsLeft,
    DateTime? blockedUntil,
    bool clearBlockedUntil = false,
  }) {
    return AppLockState(
      signedIn: signedIn ?? this.signedIn,
      locked: locked ?? this.locked,
      settingsReady: settingsReady ?? this.settingsReady,
      settings: settings ?? this.settings,
      deviceSupported: deviceSupported ?? this.deviceSupported,
      working: working ?? this.working,
      error: error ?? this.error,
      attemptsLeft: attemptsLeft ?? this.attemptsLeft,
      blockedUntil: clearBlockedUntil ? null : (blockedUntil ?? this.blockedUntil),
    );
  }

  @override
  List<Object?> get props => [
        signedIn,
        locked,
        settingsReady,
        settings,
        deviceSupported,
        working,
        error,
        attemptsLeft,
        blockedUntil,
      ];
}