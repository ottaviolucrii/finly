import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/goals/domain/entities/goal_progress.dart';
import 'package:finly/features/goals/domain/goal_sorting.dart';
import 'package:finly/features/goals/domain/repositories/goal_repository.dart';

class GetGoalProgressParams extends Equatable {
  final String workspaceId;

  /// "Now"; any time of the day. It decides what is overdue.
  final DateTime today;

  const GetGoalProgressParams({required this.workspaceId, required this.today});

  @override
  List<Object?> get props => [workspaceId, today];
}

/// The goals of a workspace with how far each one is, in the order of the
/// screen.
class GetGoalProgressUseCase implements UseCase<List<GoalProgress>, GetGoalProgressParams> {
  final GoalRepository _repository;

  const GetGoalProgressUseCase(this._repository);

  @override
  Future<Either<Failure, List<GoalProgress>>> call(GetGoalProgressParams params) async {
    if (params.workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }

    final result = await _repository.getSnapshot(params.workspaceId);
    return result.map((snapshot) {
      final items = [
        for (final goal in snapshot.goals)
          GoalProgress(
            goal: goal,
            accountName: snapshot.accountNames[goal.accountId] ?? '',
            balanceCents: snapshot.balances[goal.accountId] ?? 0,
          ),
      ];
      return sortGoals(items, params.today);
    });
  }
}
