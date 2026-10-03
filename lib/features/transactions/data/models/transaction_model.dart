import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

class TransactionModel extends TransactionEntity {
  const TransactionModel({
    required super.id,
    required super.workspaceId,
    required super.accountId,
    required super.categoryId,
    required super.type,
    required super.status,
    required super.amountCents,
    required super.currency,
    required super.description,
    required super.occurredAt,
  });

  /// [map] is a row of the `transactions` table. Timestamps arrive in UTC
  /// and are shown in the phone's local time.
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      workspaceId: map['workspace_id'] as String,
      accountId: map['account_id'] as String,
      categoryId: map['category_id'] as String?,
      type: TransactionType.fromDb(map['type'] as String),
      status: TransactionStatus.fromDb(map['status'] as String),
      amountCents: (map['amount_cents'] as num).toInt(),
      currency: map['currency'] as String,
      description: map['description'] as String,
      occurredAt: DateTime.parse(map['occurred_at'] as String).toLocal(),
    );
  }
}