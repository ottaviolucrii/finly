import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/trash/data/datasources/trash_remote_data_source.dart';
import 'package:finly/features/trash/domain/entities/trashed_transaction.dart';
import 'package:finly/features/trash/domain/entities/trashed_transfer.dart';
import 'package:finly/features/trash/domain/repositories/trash_repository.dart';

class TrashRepositoryImpl implements TrashRepository {
  final TrashRemoteDataSource _remote;

  const TrashRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<TrashedTransaction>>> getTrash(
    String workspaceId, {
    required int limit,
  }) {
    return _guard<List<TrashedTransaction>>(
      () => _remote.getTrash(workspaceId, limit: limit),
    );
  }

  @override
  Future<Either<Failure, List<TrashedTransfer>>> getTrashedTransfers(
    String workspaceId, {
    required int limit,
  }) {
    return _guard<List<TrashedTransfer>>(
      () => _remote.getTrashedTransfers(workspaceId, limit: limit),
    );
  }

  @override
  Future<Either<Failure, void>> restoreTransfer(String transferId) {
    return _guard<void>(() => _remote.restoreTransfer(transferId));
  }

  /// Runs [action]; exceptions become Left(Failure). Programming errors
  /// (Error) are mapped to an unknown_error failure and logged.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right<Failure, T>(await action());
    } catch (e) {
      return Left<Failure, T>(ErrorMapper.toFailure(e));
    }
  }
}