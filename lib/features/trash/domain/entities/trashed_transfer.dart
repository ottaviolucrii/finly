import 'package:equatable/equatable.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

/// A deleted transfer that can still be restored.
class TrashedTransfer extends Equatable {
  final String transferId;

  /// The legs of this transfer that belong to the workspace: both of them for
  /// a transfer inside the workspace, one for a transfer between the two
  /// workspaces (the other leg lives in the other workspace and is not shown
  /// here). Never empty.
  final List<TransactionEntity> legs;

  /// When it was deleted.
  final DateTime deletedAt;

  const TrashedTransfer({
    required this.transferId,
    required this.legs,
    required this.deletedAt,
  });

  /// The leg where the money left, if it is in this workspace.
  TransactionEntity? get outLeg {
    for (final leg in legs) {
      if (leg.type == TransactionType.transferOut) return leg;
    }
    return null;
  }

  /// The leg where the money arrived, if it is in this workspace.
  TransactionEntity? get inLeg {
    for (final leg in legs) {
      if (leg.type == TransactionType.transferIn) return leg;
    }
    return null;
  }

  String get description => legs.first.description;

  @override
  List<Object?> get props => [transferId, legs, deletedAt];
}