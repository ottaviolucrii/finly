import 'package:finly/features/reminders/domain/entities/reminder_items.dart';

class ReminderBillModel extends ReminderBill {
  const ReminderBillModel({
    required super.id,
    required super.description,
    required super.amountCents,
    required super.currency,
    required super.dueDate,
    super.leadDays,
  });

  /// [map] is a `transactions` row with the `recurring_transactions(lead_days)`
  /// embedded: an object when the bill comes from a recurring item, null when
  /// it does not.
  factory ReminderBillModel.fromMap(Map<String, dynamic> map) {
    final occurredAt = DateTime.parse(map['occurred_at'] as String).toLocal();

    return ReminderBillModel(
      id: map['id'] as String,
      description: map['description'] as String,
      amountCents: (map['amount_cents'] as num).toInt(),
      currency: map['currency'] as String,
      dueDate: DateTime(occurredAt.year, occurredAt.month, occurredAt.day),
      leadDays: _leadDays(map['recurring_transactions']),
    );
  }

  static int? _leadDays(Object? embedded) {
    // A to-one embed is an object; be ready for a list of one as well.
    final item = embedded is List ? (embedded.isEmpty ? null : embedded.first) : embedded;
    if (item is Map) {
      final value = item['lead_days'];
      if (value is num) return value.toInt();
    }
    return null;
  }
}
