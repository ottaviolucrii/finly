import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:finly/features/recurring/domain/entities/recurring_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

class RecurringModel extends RecurringEntity {
  const RecurringModel({
    required super.id,
    required super.workspaceId,
    required super.accountId,
    required super.categoryId,
    required super.type,
    required super.amountCents,
    required super.currency,
    required super.description,
    required super.frequency,
    required super.intervalCount,
    required super.startDate,
    required super.endDate,
    required super.isActive,
  });

  /// [map] is a row of the `recurring_transactions` table.
  factory RecurringModel.fromMap(Map<String, dynamic> map) {
    final end = map['end_date'] as String?;

    return RecurringModel(
      id: map['id'] as String,
      workspaceId: map['workspace_id'] as String,
      accountId: map['account_id'] as String,
      categoryId: map['category_id'] as String?,
      type: TransactionType.fromDb(map['type'] as String),
      amountCents: (map['amount_cents'] as num).toInt(),
      currency: map['currency'] as String,
      description: map['description'] as String,
      frequency: RecurrenceFrequency.fromDb(map['frequency'] as String),
      intervalCount: (map['interval_count'] as num).toInt(),
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: end == null ? null : DateTime.parse(end),
      isActive: map['is_active'] as bool,
    );
  }
}