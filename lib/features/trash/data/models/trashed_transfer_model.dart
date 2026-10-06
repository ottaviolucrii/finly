import 'package:finly/features/transactions/data/models/transaction_model.dart';
import 'package:finly/features/trash/domain/entities/trashed_transfer.dart';

class TrashedTransferModel extends TrashedTransfer {
  const TrashedTransferModel({
    required super.transferId,
    required super.legs,
    required super.deletedAt,
  });

  /// Groups deleted transfer legs (rows of the `transactions` table) into one
  /// entry per transfer. The entries keep the order in which each transfer
  /// first appears, and each one carries the latest deletion time of its legs.
  /// Rows with no `transfer_id` are ignored.
  static List<TrashedTransferModel> fromRows(List<Map<String, dynamic>> rows) {
    final order = <String>[];
    final legsById = <String, List<TransactionModel>>{};
    final deletedAtById = <String, DateTime>{};

    for (final row in rows) {
      final id = row['transfer_id'] as String?;
      if (id == null) continue;

      final deletedAt = DateTime.parse(row['deleted_at'] as String).toLocal();
      final known = legsById[id];
      if (known == null) {
        order.add(id);
        legsById[id] = [TransactionModel.fromMap(row)];
        deletedAtById[id] = deletedAt;
      } else {
        known.add(TransactionModel.fromMap(row));
        if (deletedAt.isAfter(deletedAtById[id]!)) deletedAtById[id] = deletedAt;
      }
    }

    return [
      for (final id in order)
        TrashedTransferModel(
          transferId: id,
          legs: legsById[id]!,
          deletedAt: deletedAtById[id]!,
        ),
    ];
  }
}