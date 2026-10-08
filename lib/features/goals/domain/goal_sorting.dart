import 'package:finly/features/goals/domain/entities/goal_progress.dart';
import 'package:finly/features/goals/domain/goal_rules.dart';

/// The order of the goals on the screen: the ones still to reach first, the
/// nearest date first and the ones with no date after; then the goals already
/// reached. Ties are broken by name. The list given is not changed.
List<GoalProgress> sortGoals(List<GoalProgress> items, DateTime today) {
  int rank(GoalProgress item) {
    switch (item.statusAt(today)) {
      case GoalStatus.overdue:
      case GoalStatus.onTrack:
        return 0;
      case GoalStatus.open:
        return 1;
      case GoalStatus.achieved:
        return 2;
    }
  }

  final sorted = [...items];
  sorted.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;

    final left = a.goal.targetDate;
    final right = b.goal.targetDate;
    if (left != null && right != null) {
      final byDate = left.compareTo(right);
      if (byDate != 0) return byDate;
    }
    return a.goal.name.toLowerCase().compareTo(b.goal.name.toLowerCase());
  });
  return sorted;
}
