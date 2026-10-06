import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/trash/domain/entities/trashed_transaction.dart';
import 'package:finly/features/trash/domain/entities/trashed_transfer.dart';

enum TrashStatus { initial, loading, loaded, failure }

class TrashState extends Equatable {
  final TrashStatus status;
  final List<TrashedTransaction> items;
  final List<TrashedTransfer> transfers;

  /// Why loading failed (shown full screen with a retry button).
  final Failure? failure;

  /// Why a restore failed (shown as a message).
  final Failure? actionFailure;

  /// The transaction just restored, so the page can say so.
  final TransactionEntity? restored;

  /// The transfer just restored, so the page can say so.
  final TrashedTransfer? restoredTransfer;

  const TrashState({
    this.status = TrashStatus.initial,
    this.items = const [],
    this.transfers = const [],
    this.failure,
    this.actionFailure,
    this.restored,
    this.restoredTransfer,
  });

  @override
  List<Object?> get props => [
        status,
        items,
        transfers,
        failure,
        actionFailure,
        restored,
        restoredTransfer,
      ];
}