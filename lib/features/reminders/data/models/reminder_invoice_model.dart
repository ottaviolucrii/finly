import 'package:finly/features/reminders/domain/entities/reminder_items.dart';

class ReminderInvoiceModel extends ReminderInvoice {
  const ReminderInvoiceModel({
    required super.id,
    required super.cardName,
    required super.totalCents,
    required super.currency,
    required super.dueDate,
  });

  /// "2026-10-17": how the database writes a date. The result is that day, with
  /// no time zone involved.
  static DateTime parseDate(String value) {
    final parts = value.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  /// Puts together an invoice row, its card and its total.
  factory ReminderInvoiceModel.fromParts({
    required Map<String, dynamic> invoice,
    required Map<String, dynamic> card,
    required int totalCents,
  }) {
    return ReminderInvoiceModel(
      id: invoice['id'] as String,
      cardName: card['name'] as String,
      totalCents: totalCents,
      currency: card['currency'] as String,
      dueDate: parseDate(invoice['due_date'] as String),
    );
  }
}
