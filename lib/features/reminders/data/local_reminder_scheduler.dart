import 'package:finly/features/reminders/domain/entities/reminder_items.dart';
import 'package:finly/features/reminders/domain/reminder_scheduler.dart';
import 'package:finly/features/reminders/reminder_texts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules the reminders as local notifications of the phone. The phone's
/// alarm system shows them, so they appear even with the app closed. Nothing
/// is sent by a server.
class LocalReminderScheduler implements ReminderScheduler {
  static const _channelId = 'finly_reminders';
  static const _channelName = 'Lembretes';
  static const _testId = 1;

  late final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// The content is "private" on the lock screen: the phone shows only that
  /// there is a notification until it is unlocked.
  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Contas a pagar e faturas do cartão que vencem em breve',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.private,
    ),
  );

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    // The app is for Brazil, and so is the database's time zone for months.
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_finly'),
      ),
    );
    _initialized = true;
  }

  @override
  Future<bool> areEnabled() async {
    try {
      await _ensureInitialized();
      return await _android?.areNotificationsEnabled() ?? false;
    } catch (e) {
      debugPrint('Checking notifications failed: $e');
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      await _ensureInitialized();
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (e) {
      debugPrint('Asking for the notification permission failed: $e');
      return false;
    }
  }

  @override
  Future<int> replaceAll(List<ScheduledReminder> reminders) async {
    await _ensureInitialized();
    await _plugin.cancelAll();

    var scheduled = 0;
    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        reminder.id,
        reminderTitle(reminder),
        reminderBody(reminder),
        tz.TZDateTime.from(reminder.at, tz.local),
        _details,
        // "Inexact": it may come a few minutes late, but it needs no special
        // permission and saves the battery.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      scheduled++;
    }
    return scheduled;
  }

  @override
  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }

  @override
  Future<void> sendTest() async {
    await _ensureInitialized();
    await _plugin.zonedSchedule(
      _testId,
      'Teste de lembrete',
      'Se você viu isto, os lembretes do Finly estão funcionando.',
      tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
