import 'package:finly/features/reminders/domain/entities/reminder_items.dart';

/// Shows notifications at a given time, even with the app closed. It is an
/// interface so tests never touch the platform.
abstract class ReminderScheduler {
  /// The user allows the app to show notifications.
  Future<bool> areEnabled();

  /// Asks for the permission (Android 13+ shows a system prompt). True when it
  /// is granted.
  Future<bool> requestPermission();

  /// Cancels every reminder and schedules [reminders] instead. Returns how many
  /// were scheduled.
  Future<int> replaceAll(List<ScheduledReminder> reminders);

  Future<void> cancelAll();

  /// Schedules one notification a few seconds from now, to check that the phone
  /// lets the app show them.
  Future<void> sendTest();
}
