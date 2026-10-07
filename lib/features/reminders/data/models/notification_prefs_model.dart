import 'package:finly/features/reminders/domain/entities/notification_prefs.dart';

class NotificationPrefsModel extends NotificationPrefs {
  const NotificationPrefsModel({
    super.billReminder,
    super.cardDue,
    super.raw,
  });

  /// [map] is the `notification_prefs` JSON object of `user_settings`.
  factory NotificationPrefsModel.fromMap(Map<String, dynamic> map) {
    return NotificationPrefsModel(
      billReminder: map['bill_reminder'] != false,
      cardDue: map['card_due'] != false,
      raw: Map<String, dynamic>.from(map),
    );
  }
}
