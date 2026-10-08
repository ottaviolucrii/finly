import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/goals/data/datasources/goal_remote_data_source.dart';
import 'package:finly/features/goals/domain/entities/goals_snapshot.dart';
import 'package:finly/features/goals/domain/repositories/goal_repository.dart';

class GoalRepositoryImpl implements GoalRepository {
  final GoalRemoteDataSource _remote;

  const GoalRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, GoalsSnapshot>> getSnapshot(String workspaceId) {
    return _guard<GoalsSnapshot>(() => _remote.getSnapshot(workspaceId));
  }

  @override
  Future<Either<Failure, void>> createGoal({
    required String workspaceId,
    required String accountId,
    required String currency,
    required String name,
    required int targetCents,
    DateTime? targetDate,
  }) {
    return _guard<void>(
      () => _remote.createGoal(
        workspaceId: workspaceId,
        accountId: accountId,
        currency: currency,
        name: name,
        targetCents: targetCents,
        targetDate: targetDate,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> updateGoal({
    required String id,
    required String accountId,
    required String name,
    required int targetCents,
    DateTime? targetDate,
  }) {
    return _guard<void>(
      () => _remote.updateGoal(
        id: id,
        accountId: accountId,
        name: name,
        targetCents: targetCents,
        targetDate: targetDate,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> archiveGoal(String id) {
    return _guard<void>(() => _remote.archiveGoal(id));
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
