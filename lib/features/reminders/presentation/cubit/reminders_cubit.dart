import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/reminders/domain/entities/notification_prefs.dart';
import 'package:finly/features/reminders/domain/reminder_scheduler.dart';
import 'package:finly/features/reminders/domain/usecases/get_notification_prefs_use_case.dart';
import 'package:finly/features/reminders/domain/usecases/save_notification_prefs_use_case.dart';
import 'package:finly/features/reminders/domain/usecases/sync_reminders_use_case.dart';
import 'package:finly/features/reminders/presentation/cubit/reminders_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Keeps the scheduled reminders in step with the data. One instance for the
/// whole app: the gate above the navigator tells it when someone signs in or
/// out, when the workspace changes, and when the app goes to the background or
/// comes back. The settings screen uses it to change the preferences.
class RemindersCubit extends Cubit<RemindersState> {
  final GetNotificationPrefsUseCase _getPrefs;
  final SaveNotificationPrefsUseCase _savePrefs;
  final SyncRemindersUseCase _syncReminders;
  final ReminderScheduler _scheduler;
  final DateTime Function() _clock;

  String? _workspaceId;
  bool _syncing = false;

  /// [clock] gives "now"; tests pass a controlled one.
  RemindersCubit({
    required GetNotificationPrefsUseCase getPrefs,
    required SaveNotificationPrefsUseCase savePrefs,
    required SyncRemindersUseCase syncReminders,
    required ReminderScheduler scheduler,
    DateTime Function()? clock,
  })  : _getPrefs = getPrefs,
        _savePrefs = savePrefs,
        _syncReminders = syncReminders,
        _scheduler = scheduler,
        _clock = clock ?? DateTime.now,
        super(const RemindersState());

  // ---- who is signed in --------------------------------------------------

  /// The active workspace is known or has changed.
  Future<void> onWorkspace(String? workspaceId) async {
    if (workspaceId == null || workspaceId.isEmpty) return;

    final changed = workspaceId != _workspaceId;
    _workspaceId = workspaceId;
    await schedule(minAge: changed ? Duration.zero : const Duration(minutes: 1));
  }

  /// Nobody is signed in: no reminder about someone's bills may stay on the
  /// phone.
  Future<void> onSignedOut() async {
    _workspaceId = null;
    try {
      await _scheduler.cancelAll();
    } catch (e) {
      debugPrint('Cancelling reminders failed: $e');
    }
    if (!isClosed) emit(const RemindersState());
  }

  /// The app is going to the background: a good moment to refresh the schedule
  /// with what was just entered.
  Future<void> onPaused() => schedule(minAge: const Duration(seconds: 30));

  Future<void> onResumed() => schedule(minAge: const Duration(minutes: 5));

  // ---- the schedule ------------------------------------------------------

  /// Rebuilds the schedule, unless it was rebuilt less than [minAge] ago.
  Future<void> schedule({Duration minAge = Duration.zero}) async {
    final workspaceId = _workspaceId;
    if (workspaceId == null || _syncing) return;

    final now = _clock();
    final last = state.lastSyncAt;
    if (last != null && now.difference(last) < minAge) return;

    _syncing = true;
    emit(state.copyWith(status: RemindersStatus.syncing, error: RemindersError.none));

    final result = await _syncReminders(
      SyncRemindersParams(workspaceId: workspaceId, now: now),
    );
    _syncing = false;
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemindersStatus.failure,
        error: RemindersError.syncFailed,
        failure: failure,
      )),
      (count) => emit(state.copyWith(
        status: RemindersStatus.done,
        scheduledCount: count,
        lastSyncAt: now,
        error: RemindersError.none,
        clearFailure: true,
      )),
    );
  }

  // ---- settings ----------------------------------------------------------

  /// Reads the preferences and the permission, for the settings screen.
  Future<void> refresh() async {
    final prefsResult = await _getPrefs(const NoParams());
    final granted = await _scheduler.areEnabled();
    if (isClosed) return;

    prefsResult.fold(
      (_) => emit(state.copyWith(permissionGranted: granted, prefsReady: true)),
      (prefs) => emit(state.copyWith(
        prefs: prefs,
        prefsReady: true,
        permissionGranted: granted,
      )),
    );
  }

  Future<void> setBillReminder(bool enabled) {
    return _updatePrefs(state.prefs.copyWith(billReminder: enabled));
  }

  Future<void> setCardDue(bool enabled) {
    return _updatePrefs(state.prefs.copyWith(cardDue: enabled));
  }

  Future<void> _updatePrefs(NotificationPrefs next) async {
    final previous = state.prefs;
    emit(state.copyWith(prefs: next, error: RemindersError.none));

    final result = await _savePrefs(next);
    var saved = true;
    result.fold((_) {
      saved = false;
    }, (_) {});

    if (!saved) {
      if (!isClosed) {
        emit(state.copyWith(prefs: previous, error: RemindersError.saveFailed));
      }
      return;
    }
    await schedule();
  }

  /// Asks the phone's permission to show notifications.
  Future<void> requestPermission() async {
    final granted = await _scheduler.requestPermission();
    if (isClosed) return;

    emit(state.copyWith(permissionGranted: granted));
    if (granted) await schedule();
  }

  /// Shows a notification in a few seconds, to check the phone allows them.
  Future<void> sendTest() async {
    try {
      await _scheduler.sendTest();
    } catch (e) {
      debugPrint('Test reminder failed: $e');
    }
  }
}
