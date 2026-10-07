import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/reminders/domain/entities/notification_prefs.dart';
import 'package:finly/features/reminders/domain/reminder_scheduler.dart';
import 'package:finly/features/reminders/domain/usecases/get_notification_prefs_use_case.dart';
import 'package:finly/features/reminders/domain/usecases/save_notification_prefs_use_case.dart';
import 'package:finly/features/reminders/domain/usecases/sync_reminders_use_case.dart';
import 'package:finly/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:finly/features/reminders/presentation/cubit/reminders_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetPrefs extends Mock implements GetNotificationPrefsUseCase {}

class MockSavePrefs extends Mock implements SaveNotificationPrefsUseCase {}

class MockSync extends Mock implements SyncRemindersUseCase {}

class MockScheduler extends Mock implements ReminderScheduler {}

void main() {
  late MockGetPrefs getPrefs;
  late MockSavePrefs savePrefs;
  late MockSync syncReminders;
  late MockScheduler scheduler;
  late DateTime now;

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const NotificationPrefs());
    registerFallbackValue(SyncRemindersParams(workspaceId: 'w', now: DateTime(2026)));
  });

  setUp(() {
    now = DateTime(2026, 10, 6, 12);
    getPrefs = MockGetPrefs();
    savePrefs = MockSavePrefs();
    syncReminders = MockSync();
    scheduler = MockScheduler();

    when(() => getPrefs(any())).thenAnswer(
      (_) async => const Right<Failure, NotificationPrefs>(NotificationPrefs()),
    );
    when(() => savePrefs(any()))
        .thenAnswer((_) async => const Right<Failure, void>(null));
    when(() => syncReminders(any()))
        .thenAnswer((_) async => const Right<Failure, int>(4));
    when(() => scheduler.areEnabled()).thenAnswer((_) async => true);
    when(() => scheduler.requestPermission()).thenAnswer((_) async => true);
    when(() => scheduler.cancelAll()).thenAnswer((_) async {});
    when(() => scheduler.sendTest()).thenAnswer((_) async {});
  });

  RemindersCubit build() {
    final cubit = RemindersCubit(
      getPrefs: getPrefs,
      savePrefs: savePrefs,
      syncReminders: syncReminders,
      scheduler: scheduler,
      clock: () => now,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  void advance(Duration time) => now = now.add(time);

  group('the schedule', () {
    test('a workspace schedules the reminders and counts them', () async {
      final cubit = build();

      await cubit.onWorkspace('w1');

      expect(cubit.state.status, RemindersStatus.done);
      expect(cubit.state.scheduledCount, 4);
      expect(cubit.state.lastSyncAt, now);
      verify(() => syncReminders(SyncRemindersParams(workspaceId: 'w1', now: now))).called(1);
    });

    test('nothing happens before there is a workspace', () async {
      final cubit = build();

      await cubit.schedule();
      await cubit.onResumed();
      await cubit.onPaused();

      verifyNever(() => syncReminders(any()));
      expect(cubit.state.status, RemindersStatus.idle);
    });

    test('an empty or missing workspace id is ignored', () async {
      final cubit = build();

      await cubit.onWorkspace(null);
      await cubit.onWorkspace('');

      verifyNever(() => syncReminders(any()));
    });

    test('a different workspace schedules at once, even right after another sync', () async {
      final cubit = build();
      await cubit.onWorkspace('w1');

      await cubit.onWorkspace('w2');

      verify(() => syncReminders(SyncRemindersParams(workspaceId: 'w2', now: now))).called(1);
    });

    test('the same workspace again within a minute does not sync twice', () async {
      final cubit = build();
      await cubit.onWorkspace('w1');

      advance(const Duration(seconds: 30));
      await cubit.onWorkspace('w1');

      verify(() => syncReminders(any())).called(1);
    });

    test('coming back soon does not sync, coming back after five minutes does', () async {
      final cubit = build();
      await cubit.onWorkspace('w1');

      advance(const Duration(minutes: 4));
      await cubit.onResumed();
      verify(() => syncReminders(any())).called(1);

      advance(const Duration(minutes: 2));
      await cubit.onResumed();
      verify(() => syncReminders(any())).called(1);
    });

    test('leaving the app syncs after thirty seconds', () async {
      final cubit = build();
      await cubit.onWorkspace('w1');

      advance(const Duration(seconds: 20));
      await cubit.onPaused();
      verify(() => syncReminders(any())).called(1);

      advance(const Duration(seconds: 20));
      await cubit.onPaused();
      verify(() => syncReminders(any())).called(1);
    });

    test('schedule with no age limit always runs', () async {
      final cubit = build();
      await cubit.onWorkspace('w1');

      await cubit.schedule();
      await cubit.schedule();

      verify(() => syncReminders(any())).called(3);
    });

    test('a failure is reported and does not count as a sync, so it is tried again', () async {
      when(() => syncReminders(any())).thenAnswer(
        (_) async => const Left<Failure, int>(NetworkFailure('network_error')),
      );
      final cubit = build();

      await cubit.onWorkspace('w1');

      expect(cubit.state.status, RemindersStatus.failure);
      expect(cubit.state.error, RemindersError.syncFailed);
      expect(cubit.state.failure, const NetworkFailure('network_error'));
      expect(cubit.state.lastSyncAt, isNull);

      when(() => syncReminders(any())).thenAnswer((_) async => const Right<Failure, int>(2));
      await cubit.onResumed();
      expect(cubit.state.status, RemindersStatus.done);
      expect(cubit.state.error, RemindersError.none);
      expect(cubit.state.failure, isNull);
    });

    test('a second request while one is running is ignored', () async {
      final gate = Completer<Either<Failure, int>>();
      when(() => syncReminders(any())).thenAnswer((_) => gate.future);
      final cubit = build();

      final first = cubit.onWorkspace('w1');
      await cubit.schedule();
      gate.complete(const Right<Failure, int>(3));
      await first;

      verify(() => syncReminders(any())).called(1);
      expect(cubit.state.scheduledCount, 3);
    });

    test('signing out cancels every reminder and forgets the workspace', () async {
      final cubit = build();
      await cubit.onWorkspace('w1');

      await cubit.onSignedOut();

      verify(() => scheduler.cancelAll()).called(1);
      expect(cubit.state, const RemindersState());

      await cubit.onResumed();
      verify(() => syncReminders(any())).called(1);
    });

    test('signing out works even if the phone fails to cancel', () async {
      when(() => scheduler.cancelAll()).thenThrow(StateError('no alarms'));
      final cubit = build();
      await cubit.onWorkspace('w1');

      await cubit.onSignedOut();

      expect(cubit.state, const RemindersState());
    });
  });

  group('the settings screen', () {
    test('refresh reads the preferences and the permission', () async {
      when(() => getPrefs(any())).thenAnswer(
        (_) async => const Right<Failure, NotificationPrefs>(
          NotificationPrefs(billReminder: false),
        ),
      );
      when(() => scheduler.areEnabled()).thenAnswer((_) async => false);
      final cubit = build();

      await cubit.refresh();

      expect(cubit.state.prefsReady, isTrue);
      expect(cubit.state.prefs.billReminder, isFalse);
      expect(cubit.state.permissionGranted, isFalse);
    });

    test('refresh with unreadable preferences keeps the defaults but still checks the permission', () async {
      when(() => getPrefs(any())).thenAnswer(
        (_) async => const Left<Failure, NotificationPrefs>(NetworkFailure('network_error')),
      );
      final cubit = build();

      await cubit.refresh();

      expect(cubit.state.prefsReady, isTrue);
      expect(cubit.state.prefs, const NotificationPrefs());
      expect(cubit.state.permissionGranted, isTrue);
    });

    test('turning bill reminders off saves and rebuilds the schedule', () async {
      final cubit = build();
      await cubit.onWorkspace('w1');

      await cubit.setBillReminder(false);

      expect(cubit.state.prefs.billReminder, isFalse);
      verify(() => savePrefs(const NotificationPrefs(billReminder: false))).called(1);
      verify(() => syncReminders(any())).called(2);
    });

    test('turning card reminders off saves and rebuilds the schedule', () async {
      final cubit = build();
      await cubit.onWorkspace('w1');

      await cubit.setCardDue(false);

      expect(cubit.state.prefs.cardDue, isFalse);
      verify(() => savePrefs(const NotificationPrefs(cardDue: false))).called(1);
    });

    test('a failed save goes back to the old switch and does not rebuild', () async {
      when(() => savePrefs(any())).thenAnswer(
        (_) async => const Left<Failure, void>(NetworkFailure('network_error')),
      );
      final cubit = build();
      await cubit.onWorkspace('w1');

      await cubit.setBillReminder(false);

      expect(cubit.state.prefs.billReminder, isTrue);
      expect(cubit.state.error, RemindersError.saveFailed);
      verify(() => syncReminders(any())).called(1);
    });

    test('a granted permission is noted and rebuilds the schedule', () async {
      final cubit = build();
      await cubit.onWorkspace('w1');

      await cubit.requestPermission();

      expect(cubit.state.permissionGranted, isTrue);
      verify(() => syncReminders(any())).called(2);
    });

    test('a refused permission is noted and nothing is scheduled', () async {
      when(() => scheduler.requestPermission()).thenAnswer((_) async => false);
      final cubit = build();
      await cubit.onWorkspace('w1');

      await cubit.requestPermission();

      expect(cubit.state.permissionGranted, isFalse);
      verify(() => syncReminders(any())).called(1);
    });

    test('the test notification is handed to the scheduler', () async {
      final cubit = build();

      await cubit.sendTest();

      verify(() => scheduler.sendTest()).called(1);
    });

    test('a failing test notification does not crash', () async {
      when(() => scheduler.sendTest()).thenThrow(StateError('no alarms'));
      final cubit = build();

      await cubit.sendTest();

      expect(cubit.state, const RemindersState());
    });
  });
}
