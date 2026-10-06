import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/trash/domain/entities/trashed_transaction.dart';

abstract class TrashRepository {
  /// The deleted incomes and expenses of a workspace, most recently deleted
  /// first. Transfers are not here: they cannot be restored one leg at a time.
  Future<Either<Failure, List<TrashedTransaction>>> getTrash(
    String workspaceId, {
    required int limit,
  });
}