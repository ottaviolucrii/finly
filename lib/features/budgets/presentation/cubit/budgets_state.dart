import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/budgets/domain/entities/budget_overview.dart';

enum BudgetsStatus { initial, loading, loaded, failure }

class BudgetsState extends Equatable {
  final BudgetsStatus status;

  /// The month being shown (its first day).
  final DateTime month;
  final BudgetOverview? overview;

  /// Why loading failed (shown full screen with a retry button).
  final Failure? failure;

  /// Why an action such as removing a budget failed (shown as a message).
  final Failure? actionFailure;

  const BudgetsState({
    this.status = BudgetsStatus.initial,
    required this.month,
    this.overview,
    this.failure,
    this.actionFailure,
  });

  @override
  List<Object?> get props => [status, month, overview, failure, actionFailure];
}