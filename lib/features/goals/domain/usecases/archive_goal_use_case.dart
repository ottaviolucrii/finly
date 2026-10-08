import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/goals/domain/repositories/goal_repository.dart';

/// Archives a goal (it is not deleted: the history keeps it).
class ArchiveGoalUseCase implements UseCase<void, String> {
  final GoalRepository _repository;

  const ArchiveGoalUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(String goalId) async {
    if (goalId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_goal'));
    }
    return _repository.archiveGoal(goalId);
  }
}
