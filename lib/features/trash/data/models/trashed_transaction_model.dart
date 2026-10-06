import 'package:finly/features/transactions/data/models/transaction_model.dart';
import 'package:finly/features/trash/domain/entities/trashed_transaction.dart';

class TrashedTransactionModel extends TrashedTransaction {
  const TrashedTransactionModel({
    required super.transaction,
    required super.deletedAt,
  });

  /// [map] is a row of the `transactions` table with `deleted_at` set.
  factory TrashedTransactionModel.fromMap(Map<String, dynamic> map) {
    return TrashedTransactionModel(
      transaction: TransactionModel.fromMap(map),
      deletedAt: DateTime.parse(map['deleted_at'] as String).toLocal(),
    );
  }
}