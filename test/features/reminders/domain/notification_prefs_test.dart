import 'package:finly/features/reminders/domain/entities/notification_prefs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationPrefs.fromMap', () {
    test('reads the two switches', () {
      final prefs = NotificationPrefs.fromMap({'bill_reminder': false, 'card_due': true});

      expect(prefs.billReminder, isFalse);
      expect(prefs.cardDue, isTrue);
    });

    test('a missing key means on, like the database default', () {
      final prefs = NotificationPrefs.fromMap({});

      expect(prefs.billReminder, isTrue);
      expect(prefs.cardDue, isTrue);
    });

    test('keeps the keys this app does not use', () {
      final prefs = NotificationPrefs.fromMap({
        'budget_alert': true,
        'low_balance': false,
        'bill_reminder': true,
        'card_due': true,
      });

      expect(prefs.raw['budget_alert'], isTrue);
      expect(prefs.raw['low_balance'], isFalse);
    });
  });

  group('toMap', () {
    test('writes the two switches', () {
      const prefs = NotificationPrefs(billReminder: false, cardDue: true);

      expect(prefs.toMap(), {'bill_reminder': false, 'card_due': true});
    });

    test('saving never loses a key it does not use', () {
      final prefs = NotificationPrefs.fromMap({
        'budget_alert': true,
        'pending_digest': false,
        'bill_reminder': true,
        'card_due': true,
      }).copyWith(billReminder: false);

      final map = prefs.toMap();

      expect(map['budget_alert'], isTrue);
      expect(map['pending_digest'], isFalse);
      expect(map['bill_reminder'], isFalse);
      expect(map['card_due'], isTrue);
    });
  });

  group('copyWith and anyEnabled', () {
    test('changes one switch and keeps the other', () {
      const prefs = NotificationPrefs();

      expect(prefs.copyWith(cardDue: false).billReminder, isTrue);
      expect(prefs.copyWith(billReminder: false).cardDue, isTrue);
    });

    test('anyEnabled is false only when both are off', () {
      expect(const NotificationPrefs().anyEnabled, isTrue);
      expect(const NotificationPrefs(billReminder: false).anyEnabled, isTrue);
      expect(const NotificationPrefs(cardDue: false).anyEnabled, isTrue);
      expect(
        const NotificationPrefs(billReminder: false, cardDue: false).anyEnabled,
        isFalse,
      );
    });

    test('preferences with the same values are equal', () {
      expect(const NotificationPrefs(), const NotificationPrefs());
      expect(
        const NotificationPrefs(),
        isNot(const NotificationPrefs(billReminder: false)),
      );
    });
  });
}
