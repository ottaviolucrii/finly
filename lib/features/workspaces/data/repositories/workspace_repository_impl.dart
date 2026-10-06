import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/workspaces/data/datasources/workspace_remote_data_source.dart';
import 'package:finly/features/workspaces/domain/repositories/workspace_repository.dart';

class WorkspaceRepositoryImpl implements WorkspaceRepository {
  final WorkspaceRemoteDataSource _remote;

  const WorkspaceRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, WorkspaceEntity>> createWorkspace({
    required String name,
    required WorkspaceType type,
    required String taxId,
  }) async {
    try {
      final workspace = await _remote.createWorkspace(
        name: name,
        type: type,
        taxId: taxId,
      );
      return Right<Failure, WorkspaceEntity>(workspace);
    } catch (e) {
      return Left<Failure, WorkspaceEntity>(ErrorMapper.toFailure(e));
    }
  }
}