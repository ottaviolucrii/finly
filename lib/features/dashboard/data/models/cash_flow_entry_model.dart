import 'package:finly/features/dashboard/domain/entities/cash_flow_entry.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

class CashFlowEntryModel extends CashFlowEntry {
  const CashFlowEntryModel({
    required super.type,
    required super.status,
    required super.currency,
    required super.amountCents,
  });

  /// [map] holds the four columns the dashboard asks of `transactions`.
  factory CashFlowEntryModel.fromMap(Map<String, dynamic> map) {
    return CashFlowEntryModel(
      type: TransactionType.fromDb(map['type'] as String),
      status: TransactionStatus.fromDb(map['status'] as String),
      currency: map['currency'] as String,
      amountCents: (map['amount_cents'] as num).toInt(),
    );
  }
}