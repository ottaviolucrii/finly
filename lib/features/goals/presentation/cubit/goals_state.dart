import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/goals/domain/entities/goal_progress.dart';

enum GoalsStatus { loading, loaded, failure }

class GoalsState extends Equatable {
  final GoalsStatus status;

  /// The goals in the order of the screen. They stay while a reload runs.
  final List<GoalProgress> items;

  /// The day the list was made for: it decides what is overdue.
  final DateTime? today;
  final Failure? failure;

  const GoalsState({
    this.status = GoalsStatus.loading,
    this.items = const [],
    this.today,
    this.failure,
  });

  @override
  List<Object?> get props => [status, items, today, failure];
}
