import 'package:finly/features/goals/domain/usecases/get_goal_progress_use_case.dart';
import 'package:finly/features/goals/presentation/cubit/goals_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GoalsCubit extends Cubit<GoalsState> {
  final GetGoalProgressUseCase _getProgress;
  final DateTime Function() _clock;
  String? _workspaceId;

  /// [clock] gives "now"; tests pass a fixed date.
  GoalsCubit(this._getProgress, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        super(const GoalsState());

  Future<void> load(String workspaceId) {
    _workspaceId = workspaceId;
    return reload();
  }

  Future<void> reload() async {
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;

    emit(GoalsState(
      status: GoalsStatus.loading,
      items: state.items,
      today: state.today,
    ));

    final now = _clock();
    final result = await _getProgress(
      GetGoalProgressParams(workspaceId: workspaceId, today: now),
    );
    if (isClosed) return;

    emit(result.fold<GoalsState>(
      (failure) => GoalsState(
        status: GoalsStatus.failure,
        items: state.items,
        today: state.today,
        failure: failure,
      ),
      (items) => GoalsState(
        status: GoalsStatus.loaded,
        items: items,
        today: DateTime(now.year, now.month, now.day),
      ),
    ));
  }
}
