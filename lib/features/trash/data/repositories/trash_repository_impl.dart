import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/trash/data/datasources/trash_remote_data_source.dart';
import 'package:finly/features/trash/domain/entities/trashed_transaction.dart';
import 'package:finly/features/trash/domain/repositories/trash_repository.dart';

class TrashRepositoryImpl implements TrashRepository {
  final TrashRemoteDataSource _remote;

  const TrashRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, List<TrashedTransaction>>> getTrash(
    String workspaceId, {
    required int limit,
  }) async {
    try {
      return Right<Failure, List<TrashedTransaction>>(
        await _remote.getTrash(workspaceId, limit: limit),
      );
    } catch (e) {
      return Left<Failure, List<TrashedTransaction>>(ErrorMapper.toFailure(e));
    }
  }
}