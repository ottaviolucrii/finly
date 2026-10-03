import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transfers/domain/entities/transfer_kind.dart';

abstract class TransferRepository {
  /// Creates the two linked entries and returns the transfer id. When the
  /// accounts use different currencies, [toAmountCents] is the amount that
  /// arrives; otherwise it is null.
  Future<Either<Failure, String>> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required int amountCents,
    int? toAmountCents,
    required String description,
    required DateTime occurredAt,
    required TransferKind kind,
  });

  /// Soft-deletes both entries of the transfer.
  Future<Either<Failure, void>> deleteTransfer(String transferId);
}