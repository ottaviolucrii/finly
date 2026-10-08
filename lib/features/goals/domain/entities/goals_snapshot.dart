import 'package:equatable/equatable.dart';
import 'package:finly/features/goals/domain/entities/goal.dart';

/// What the goals screen is made from: the goals that are not archived, the
/// balance of every account of the workspace and the names of the accounts.
class GoalsSnapshot extends Equatable {
  final List<Goal> goals;

  /// Posted balance per account id.
  final Map<String, int> balances;

  /// Name per account id.
  final Map<String, String> accountNames;

  const GoalsSnapshot({
    this.goals = const [],
    this.balances = const {},
    this.accountNames = const {},
  });

  @override
  List<Object?> get props => [goals, balances, accountNames];
}
