import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/trash/domain/entities/trashed_transaction.dart';
import 'package:finly/features/trash/domain/entities/trashed_transfer.dart';

abstract class TrashRepository {
  /// The deleted incomes and expenses of a workspace, most recently deleted
  /// first. Transfers are listed by [getTrashedTransfers].
  Future<Either<Failure, List<TrashedTransaction>>> getTrash(
    String workspaceId, {
    required int limit,
  });

  /// The deleted transfers that have a leg in the workspace, most recently
  /// deleted first.
  Future<Either<Failure, List<TrashedTransfer>>> getTrashedTransfers(
    String workspaceId, {
    required int limit,
  });

  /// Brings a deleted transfer back, both legs together (even the leg in the
  /// other workspace). The database refuses a card invoice payment.
  Future<Either<Failure, void>> restoreTransfer(String transferId);
}