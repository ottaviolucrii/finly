import 'package:finly/core/security/device_authenticator.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/lock/domain/attempt_limiter.dart';
import 'package:finly/features/lock/domain/entities/lock_settings.dart';
import 'package:finly/features/lock/domain/lock_policy.dart';
import 'package:finly/features/lock/domain/usecases/get_lock_settings_use_case.dart';
import 'package:finly/features/lock/domain/usecases/save_lock_settings_use_case.dart';
import 'package:finly/features/lock/domain/usecases/verify_password_use_case.dart';
import 'package:finly/features/lock/presentation/cubit/app_lock_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The session lock (SRS FR-A07 to FR-A09). One instance for the whole app: the
/// gate above the navigator tells it when the app goes to the background, when
/// the user touches the screen, and when someone signs in or out.
class AppLockCubit extends Cubit<AppLockState> {
  final GetLockSettingsUseCase _getSettings;
  final SaveLockSettingsUseCase _saveSettings;
  final VerifyPasswordUseCase _verifyPassword;
  final DeviceAuthenticator _device;
  final DateTime Function() _clock;

  AttemptLimiter _limiter = const AttemptLimiter();
  DateTime? _backgroundedAt;
  late DateTime _lastActivity;

  /// The phone's own prompt is on screen. It sends the app to the background
  /// for a moment, which must not lock it.
  bool _authenticating = false;

  /// [clock] gives "now"; tests pass a controlled one.
  AppLockCubit({
    required GetLockSettingsUseCase getSettings,
    required SaveLockSettingsUseCase saveSettings,
    required VerifyPasswordUseCase verifyPassword,
    required DeviceAuthenticator device,
    DateTime Function()? clock,
  })  : _getSettings = getSettings,
        _saveSettings = saveSettings,
        _verifyPassword = verifyPassword,
        _device = device,
        _clock = clock ?? DateTime.now,
        super(const AppLockState()) {
    _lastActivity = _clock();
  }

  // ---- who is signed in --------------------------------------------------

  /// The app started with a saved login: it stays locked until unlocked.
  Future<void> onSessionRestored() async {
    emit(state.copyWith(signedIn: true, locked: true));
    await _loadSettings();
  }

  /// Someone has just typed their password to sign in: no lock on top of it.
  void unlockForSignIn() {
    if (state.locked) emit(state.copyWith(locked: false));
  }

  Future<void> onSignedIn() async {
    _lastActivity = _clock();
    emit(state.copyWith(signedIn: true, locked: false));
    await _loadSettings();
  }

  void onSignedOut() {
    _limiter = const AttemptLimiter();
    _backgroundedAt = null;
    emit(const AppLockState(locked: false));
  }

  Future<void> _loadSettings() async {
    final supported = await _device.isSupported();
    final result = await _getSettings(const NoParams());
    // Someone may have signed out while this was waiting.
    if (!state.signedIn) return;

    result.fold(
      // Without the settings, the defaults apply: 2 minutes, no biometrics.
      (_) => emit(state.copyWith(deviceSupported: supported, settingsReady: true)),
      (settings) => emit(state.copyWith(
        settings: settings,
        deviceSupported: supported,
        settingsReady: true,
      )),
    );
  }

  // ---- when to lock ------------------------------------------------------

  /// Any touch on the screen counts as use.
  void onUserActivity() => _lastActivity = _clock();

  void onBackgrounded() {
    if (!state.signedIn || state.locked) return;
    _backgroundedAt ??= _clock();
  }

  void onResumed() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null || !state.signedIn || state.locked || _authenticating) {
      return;
    }

    final now = _clock();
    if (shouldLockAfterBackground(state.settings, since, now)) {
      emit(state.copyWith(locked: true, error: LockError.none));
    } else {
      _lastActivity = now;
    }
  }

  /// Called every few seconds while the app is open.
  void checkIdle() {
    if (!state.signedIn || state.locked || _authenticating) return;
    if (shouldLockForIdle(state.settings, _lastActivity, _clock())) {
      emit(state.copyWith(locked: true, error: LockError.none));
    }
  }

  void lockNow() {
    if (state.signedIn && !state.locked) {
      emit(state.copyWith(locked: true, error: LockError.none));
    }
  }

  // ---- unlocking ---------------------------------------------------------

  Future<void> unlockWithDevice() async {
    if (state.working || !state.locked) return;

    emit(state.copyWith(working: true, error: LockError.none));
    final ok = await _askDevice('Desbloqueie o Finly');

    if (ok) {
      _lastActivity = _clock();
      emit(state.copyWith(locked: false, working: false, error: LockError.none));
    } else {
      emit(state.copyWith(working: false, error: LockError.deviceFailed));
    }
  }

  Future<void> unlockWithPassword(String password) async {
    if (state.working || !state.locked) return;

    final now = _clock();
    if (_limiter.isBlocked(now)) {
      emit(state.copyWith(
        error: LockError.blocked,
        attemptsLeft: 0,
        blockedUntil: _limiter.blockedUntil,
      ));
      return;
    }

    emit(state.copyWith(working: true, error: LockError.none));
    final result = await _verifyPassword(password);

    result.fold(
      (failure) {
        switch (failure.message) {
          case 'invalid_credentials':
            _limiter = _limiter.recordFailure(_clock());
            final blocked = _limiter.isBlocked(_clock());
            emit(state.copyWith(
              working: false,
              error: blocked ? LockError.blocked : LockError.wrongPassword,
              attemptsLeft: blocked ? 0 : _limiter.attemptsLeft,
              blockedUntil: _limiter.blockedUntil,
              clearBlockedUntil: _limiter.blockedUntil == null,
            ));
          case 'network_error':
            // Not the user's fault: it does not count as a wrong password.
            emit(state.copyWith(working: false, error: LockError.network));
          case 'rate_limited':
            emit(state.copyWith(working: false, error: LockError.rateLimited));
          default:
            emit(state.copyWith(working: false, error: LockError.other));
        }
      },
      (_) {
        _limiter = const AttemptLimiter();
        _lastActivity = _clock();
        emit(state.copyWith(
          locked: false,
          working: false,
          error: LockError.none,
          attemptsLeft: AttemptLimiter.maxFailures,
          clearBlockedUntil: true,
        ));
      },
    );
  }

  Future<bool> _askDevice(String reason) async {
    _authenticating = true;
    try {
      return await _device.authenticate(reason: reason);
    } finally {
      _authenticating = false;
    }
  }

  // ---- settings ----------------------------------------------------------

  Future<void> setTimeout(int seconds) async {
    if (!lockTimeoutOptions.contains(seconds)) return;
    await _save(state.settings.copyWith(timeoutSeconds: seconds));
  }

  /// Turning it on first asks the phone to confirm, so a sensor that does not
  /// work cannot lock the user out. Turning it off just saves.
  Future<void> setBiometric(bool enabled) async {
    emit(state.copyWith(error: LockError.none));

    if (enabled) {
      if (!state.deviceSupported) {
        emit(state.copyWith(error: LockError.biometricUnavailable));
        return;
      }
      final ok = await _askDevice('Confirme para ativar o desbloqueio por biometria');
      if (!ok) {
        emit(state.copyWith(error: LockError.biometricNotConfirmed));
        return;
      }
    }
    await _save(state.settings.copyWith(biometricEnabled: enabled));
  }

  Future<void> _save(LockSettings next) async {
    final previous = state.settings;
    emit(state.copyWith(settings: next, error: LockError.none));

    final result = await _saveSettings(next);
    result.fold(
      (_) => emit(state.copyWith(settings: previous, error: LockError.saveFailed)),
      (_) {},
    );
  }
}