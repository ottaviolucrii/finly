import 'package:equatable/equatable.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';

/// A deleted transaction that can still be restored.
class TrashedTransaction extends Equatable {
  final TransactionEntity transaction;

  /// When it was deleted.
  final DateTime deletedAt;

  const TrashedTransaction({
    required this.transaction,
    required this.deletedAt,
  });

  @override
  List<Object?> get props => [transaction, deletedAt];
}