import 'package:finly/features/budgets/domain/budget_rules.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/budgets/domain/usecases/get_budget_overview_use_case.dart';
import 'package:finly/features/budgets/domain/usecases/stop_budget_use_case.dart';
import 'package:finly/features/budgets/presentation/cubit/budgets_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BudgetsCubit extends Cubit<BudgetsState> {
  final GetBudgetOverviewUseCase _getOverview;
  final StopBudgetUseCase _stopBudget;
  String? _workspaceId;

  /// [clock] gives "today"; tests pass a fixed date.
  BudgetsCubit({
    required GetBudgetOverviewUseCase getOverview,
    required StopBudgetUseCase stopBudget,
    DateTime Function()? clock,
  })  : _getOverview = getOverview,
        _stopBudget = stopBudget,
        super(BudgetsState(month: monthStart((clock ?? DateTime.now)())));

  /// Loads the current month of [workspaceId].
  Future<void> load(String workspaceId) async {
    _workspaceId = workspaceId;
    await _fetch(state.month);
  }

  /// Moves to the previous (-1) or next (+1) month.
  Future<void> changeMonth(int delta) => _fetch(addMonths(state.month, delta));

  Future<void> reload() => _fetch(state.month);

  Future<void> _fetch(DateTime month) async {
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;

    // Keep the old data on screen while reloading the same month. Another
    // month starts empty, so last month's numbers never sit under a new title.
    emit(BudgetsState(
      status: BudgetsStatus.loading,
      month: month,
      overview: month == state.month ? state.overview : null,
    ));

    final result = await _getOverview(
      GetBudgetOverviewParams(workspaceId: workspaceId, month: month),
    );
    emit(result.fold<BudgetsState>(
      (failure) => BudgetsState(
        status: BudgetsStatus.failure,
        month: month,
        failure: failure,
      ),
      (overview) => BudgetsState(
        status: BudgetsStatus.loaded,
        month: month,
        overview: overview,
      ),
    ));
  }

  /// Stops a budget from the month being shown onward. Earlier months keep
  /// it: the database stores an end marker, nothing is deleted.
  Future<void> stopBudget(BudgetProgress item) async {
    final result = await _stopBudget(
      StopBudgetParams(
        workspaceId: item.budget.workspaceId,
        categoryId: item.category.id,
        month: state.month,
        currency: item.currency,
      ),
    );
    await result.fold<Future<void>>(
      (failure) async => emit(BudgetsState(
        status: BudgetsStatus.loaded,
        month: state.month,
        overview: state.overview,
        actionFailure: failure,
      )),
      (_) => reload(),
    );
  }
}