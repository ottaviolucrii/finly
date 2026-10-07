import 'package:equatable/equatable.dart';

/// Which reminders the user wants. They live in `user_settings.notification_prefs`
/// (a JSON object). Keys this app does not use are kept as they are, so saving
/// never loses one.
class NotificationPrefs extends Equatable {
  /// Pending bills: a reminder before the due date and one on the due day.
  final bool billReminder;

  /// Credit card invoices: a reminder 3 days before and one on the due day.
  final bool cardDue;

  /// Every key of the stored object.
  final Map<String, dynamic> raw;

  const NotificationPrefs({
    this.billReminder = true,
    this.cardDue = true,
    this.raw = const {},
  });

  /// A missing key means "on", like the default the database gives.
  factory NotificationPrefs.fromMap(Map<String, dynamic> map) {
    return NotificationPrefs(
      billReminder: map['bill_reminder'] != false,
      cardDue: map['card_due'] != false,
      raw: Map<String, dynamic>.from(map),
    );
  }

  Map<String, dynamic> toMap() => {
        ...raw,
        'bill_reminder': billReminder,
        'card_due': cardDue,
      };

  /// At least one kind of reminder is on.
  bool get anyEnabled => billReminder || cardDue;

  NotificationPrefs copyWith({bool? billReminder, bool? cardDue}) {
    return NotificationPrefs(
      billReminder: billReminder ?? this.billReminder,
      cardDue: cardDue ?? this.cardDue,
      raw: raw,
    );
  }

  @override
  List<Object?> get props => [billReminder, cardDue, raw];
}
