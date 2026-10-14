import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The id of the monthly notification. The reminders keep their hands off it
/// (see LocalReminderScheduler.replaceAll).
const monthlySummaryNotificationId = 424242;

/// The optional notification of the monthly summary: on the 1st of every
/// month, at 9am. The text is the same every month and tells nothing about
/// the person's money.
abstract class SummaryNotifier {
  Future<bool> isEnabled();

  /// Turns it on (asking for the permission) or off. False when it could not
  /// be turned on.
  Future<bool> setEnabled(bool enabled);

  /// Schedules it again when it is on (a new sign in, a phone restart).
  Future<void> rearm();
}

class LocalSummaryNotifier implements SummaryNotifier {
  static const _prefKey = 'summary.notify';
  static const _channelId = 'finly_summary';

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Resumo do mês',
      channelDescription: 'Um aviso no dia 1 de cada mês com o resumo do mês que passou',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      visibility: NotificationVisibility.private,
    ),
  );

  late final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@drawable/ic_stat_finly')),
    );
    _initialized = true;
  }

  @override
  Future<bool> isEnabled() async => (await SharedPreferences.getInstance()).getBool(_prefKey) ?? false;

  @override
  Future<bool> setEnabled(bool enabled) async {
    try {
      await _ensureInitialized();
      final prefs = await SharedPreferences.getInstance();
      if (!enabled) {
        await _plugin.cancel(monthlySummaryNotificationId);
        await prefs.setBool(_prefKey, false);
        return true;
      }
      final granted = await _android?.requestNotificationsPermission() ?? false;
      if (!granted) return false;
      await _schedule();
      await prefs.setBool(_prefKey, true);
      return true;
    } catch (e) {
      debugPrint('Changing the monthly summary notification failed: $e');
      return false;
    }
  }

  @override
  Future<void> rearm() async {
    try {
      if (!await isEnabled()) return;
      await _schedule();
    } catch (e) {
      debugPrint('Scheduling the monthly summary notification failed: $e');
    }
  }

  /// The next 1st at 9am (today, if today is the 1st and it is not 9am yet),
  /// repeating every month.
  Future<void> _schedule() async {
    await _ensureInitialized();
    final now = tz.TZDateTime.now(tz.local);
    var first = tz.TZDateTime(tz.local, now.year, now.month, 1, 9);
    if (!first.isAfter(now)) {
      final year = now.month == 12 ? now.year + 1 : now.year;
      final month = now.month == 12 ? 1 : now.month + 1;
      first = tz.TZDateTime(tz.local, year, month, 1, 9);
    }
    await _plugin.zonedSchedule(
      monthlySummaryNotificationId,
      'Seu resumo do mês está pronto',
      'Veja como foi o mês que passou no Finly.',
      first,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }
}
