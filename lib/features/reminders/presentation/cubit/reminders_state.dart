import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/reminders/domain/entities/notification_prefs.dart';

enum RemindersStatus { idle, syncing, done, failure }

/// What went wrong, for the settings screen to say.
enum RemindersError { none, saveFailed, syncFailed }

class RemindersState extends Equatable {
  final RemindersStatus status;
  final NotificationPrefs prefs;

  /// The preferences were read (the switches can be used).
  final bool prefsReady;

  /// The user allows notifications. Null until it was checked.
  final bool? permissionGranted;

  /// How many reminders are scheduled right now.
  final int scheduledCount;

  /// When the schedule was last rebuilt with success.
  final DateTime? lastSyncAt;
  final RemindersError error;
  final Failure? failure;

  const RemindersState({
    this.status = RemindersStatus.idle,
    this.prefs = const NotificationPrefs(),
    this.prefsReady = false,
    this.permissionGranted,
    this.scheduledCount = 0,
    this.lastSyncAt,
    this.error = RemindersError.none,
    this.failure,
  });

  RemindersState copyWith({
    RemindersStatus? status,
    NotificationPrefs? prefs,
    bool? prefsReady,
    bool? permissionGranted,
    int? scheduledCount,
    DateTime? lastSyncAt,
    RemindersError? error,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return RemindersState(
      status: status ?? this.status,
      prefs: prefs ?? this.prefs,
      prefsReady: prefsReady ?? this.prefsReady,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      scheduledCount: scheduledCount ?? this.scheduledCount,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      error: error ?? this.error,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
        status,
        prefs,
        prefsReady,
        permissionGranted,
        scheduledCount,
        lastSyncAt,
        error,
        failure,
      ];
}
