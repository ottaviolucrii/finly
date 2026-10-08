import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/goals/domain/entities/goals_snapshot.dart';

abstract class GoalRepository {
  /// The goals of [workspaceId] that are not archived, with the balances and
  /// names of its accounts.
  Future<Either<Failure, GoalsSnapshot>> getSnapshot(String workspaceId);

  Future<Either<Failure, void>> createGoal({
    required String workspaceId,
    required String accountId,
    required String currency,
    required String name,
    required int targetCents,
    DateTime? targetDate,
  });

  /// Changes a goal. A null [targetDate] removes the date.
  Future<Either<Failure, void>> updateGoal({
    required String id,
    required String accountId,
    required String name,
    required int targetCents,
    DateTime? targetDate,
  });

  /// Archives a goal: it leaves the list and its name can be used again.
  Future<Either<Failure, void>> archiveGoal(String id);
}
