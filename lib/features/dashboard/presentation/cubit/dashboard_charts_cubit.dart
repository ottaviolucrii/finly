import 'package:finly/features/dashboard/domain/usecases/get_dashboard_charts_use_case.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_charts_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DashboardChartsCubit extends Cubit<DashboardChartsState> {
  final GetDashboardChartsUseCase _getCharts;
  final DateTime Function() _clock;
  String? _workspaceId;

  /// [clock] gives "now"; tests pass a fixed date.
  DashboardChartsCubit(this._getCharts, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        super(const DashboardChartsState());

  Future<void> load(String workspaceId) async {
    _workspaceId = workspaceId;
    // Keep the old charts on screen while reloading, to avoid flicker.
    emit(DashboardChartsState(
      status: DashboardChartsStatus.loading,
      charts: state.charts,
    ));

    final result = await _getCharts(
      GetDashboardChartsParams(workspaceId: workspaceId, today: _clock()),
    );
    emit(result.fold<DashboardChartsState>(
      (failure) => DashboardChartsState(
        status: DashboardChartsStatus.failure,
        charts: state.charts,
        failure: failure,
      ),
      (charts) => DashboardChartsState(
        status: DashboardChartsStatus.loaded,
        charts: charts,
      ),
    ));
  }

  Future<void> reload() async {
    final id = _workspaceId;
    if (id != null) await load(id);
  }
}