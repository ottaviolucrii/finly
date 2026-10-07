import 'package:finly/features/lock/domain/entities/lock_settings.dart';

/// Whether coming back to the app should lock it. With "immediately" it always
/// does; otherwise only after the app stayed away for the chosen time.
bool shouldLockAfterBackground(
  LockSettings settings,
  DateTime backgroundedAt,
  DateTime now,
) {
  if (settings.locksImmediately) return true;
  return now.difference(backgroundedAt) >= settings.timeout;
}

/// Whether the app, still on screen, was left alone long enough to lock.
/// "Immediately" means "when it goes to the background", so it never locks a
/// screen the user is looking at.
bool shouldLockForIdle(
  LockSettings settings,
  DateTime lastActivity,
  DateTime now,
) {
  if (settings.locksImmediately) return false;
  return now.difference(lastActivity) >= settings.timeout;
}