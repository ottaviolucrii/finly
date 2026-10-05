import 'package:finly/features/dashboard/domain/usecases/get_dashboard_use_case.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final GetDashboardUseCase _getDashboard;
  final DateTime Function() _clock;
  String? _workspaceId;

  /// [clock] gives "now"; tests pass a fixed date.
  DashboardCubit(this._getDashboard, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        super(const DashboardState());

  Future<void> load(String workspaceId) async {
    _workspaceId = workspaceId;
    // Keep the old numbers on screen while reloading, to avoid flicker.
    emit(DashboardState(status: DashboardStatus.loading, data: state.data));

    final result = await _getDashboard(
      GetDashboardParams(workspaceId: workspaceId, today: _clock()),
    );
    emit(result.fold<DashboardState>(
      (failure) => DashboardState(
        status: DashboardStatus.failure,
        data: state.data,
        failure: failure,
      ),
      (data) => DashboardState(status: DashboardStatus.loaded, data: data),
    ));
  }

  Future<void> reload() async {
    final id = _workspaceId;
    if (id != null) await load(id);
  }
}