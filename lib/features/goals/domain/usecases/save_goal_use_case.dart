import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/goals/domain/repositories/goal_repository.dart';

class SaveGoalParams extends Equatable {
  /// Null creates a goal; an id changes that goal.
  final String? id;
  final String workspaceId;
  final String accountId;
  final String currency;
  final String name;
  final int targetCents;
  final DateTime? targetDate;

  const SaveGoalParams({
    required this.workspaceId,
    required this.accountId,
    required this.currency,
    required this.name,
    required this.targetCents,
    this.id,
    this.targetDate,
  });

  @override
  List<Object?> get props =>
      [id, workspaceId, accountId, currency, name, targetCents, targetDate];
}

/// Creates or changes a goal, after checking what the database would refuse.
class SaveGoalUseCase implements UseCase<void, SaveGoalParams> {
  /// The longest name of a goal, like the database.
  static const maxNameLength = 80;

  /// The biggest target: 10 billion reais.
  static const maxTargetCents = 1000000000000;

  final GoalRepository _repository;

  const SaveGoalUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(SaveGoalParams params) async {
    final name = params.name.trim();

    if (params.workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }
    if (params.accountId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_account'));
    }
    if (name.isEmpty || name.length > maxNameLength) {
      return const Left(ValidationFailure('invalid_name'));
    }
    if (params.targetCents <= 0 || params.targetCents > maxTargetCents) {
      return const Left(ValidationFailure('invalid_target'));
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(params.currency)) {
      return const Left(ValidationFailure('invalid_currency'));
    }

    final id = params.id;
    if (id == null) {
      return _repository.createGoal(
        workspaceId: params.workspaceId,
        accountId: params.accountId,
        currency: params.currency,
        name: name,
        targetCents: params.targetCents,
        targetDate: params.targetDate,
      );
    }
    return _repository.updateGoal(
      id: id,
      accountId: params.accountId,
      name: name,
      targetCents: params.targetCents,
      targetDate: params.targetDate,
    );
  }
}
