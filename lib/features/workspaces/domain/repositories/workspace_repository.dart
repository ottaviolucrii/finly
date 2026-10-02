import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';

abstract class WorkspaceRepository {
  /// Creates a workspace for the signed-in user. The server validates the tax
  /// id again, seeds the default categories and activates the workspace when
  /// it is the user's first one.
  Future<Either<Failure, WorkspaceEntity>> createWorkspace({
    required String name,
    required WorkspaceType type,
    required String taxId,
  });
}