import 'package:equatable/equatable.dart';
import 'package:finly/features/goals/domain/entities/goal.dart';
import 'package:finly/features/goals/domain/goal_rules.dart';

/// A goal with how far it is: the balance of its account against the target.
class GoalProgress extends Equatable {
  final Goal goal;

  /// The name of the account the goal follows.
  final String accountName;

  /// The posted balance of that account (can be negative).
  final int balanceCents;

  const GoalProgress({
    required this.goal,
    required this.accountName,
    required this.balanceCents,
  });

  int get savedCents => savedFor(balanceCents);

  int get percent => progressPercent(savedCents, goal.targetCents);

  int get remainingCents => remainingFor(savedCents, goal.targetCents);

  bool get achieved => savedCents >= goal.targetCents;

  GoalStatus statusAt(DateTime today) => goalStatusFor(
        savedCents: savedCents,
        targetCents: goal.targetCents,
        targetDate: goal.targetDate,
        today: today,
      );

  /// What to put aside each month to be on time, or null when it does not apply.
  int? monthlyNeededAt(DateTime today) {
    final date = goal.targetDate;
    if (date == null) return null;
    return monthlyNeededFor(remainingCents, daysLeft(today, date));
  }

  @override
  List<Object?> get props => [goal, accountName, balanceCents];
}
