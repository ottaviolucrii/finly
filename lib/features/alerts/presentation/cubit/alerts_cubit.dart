import 'package:finly/features/alerts/domain/usecases/get_alerts_use_case.dart';
import 'package:finly/features/alerts/presentation/cubit/alerts_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AlertsCubit extends Cubit<AlertsState> {
  final GetAlertsUseCase _getAlerts;
  final DateTime Function() _clock;
  String? _workspaceId;

  /// [clock] gives "now"; tests pass a fixed date.
  AlertsCubit(this._getAlerts, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        super(const AlertsState());

  Future<void> load(String workspaceId) async {
    _workspaceId = workspaceId;
    emit(AlertsState(status: AlertsStatus.loading, alerts: state.alerts));

    final result = await _getAlerts(
      GetAlertsParams(workspaceId: workspaceId, today: _clock()),
    );
    emit(result.fold<AlertsState>(
      (failure) => AlertsState(
        status: AlertsStatus.failure,
        alerts: state.alerts,
        failure: failure,
      ),
      (alerts) => AlertsState(status: AlertsStatus.loaded, alerts: alerts),
    ));
  }

  Future<void> reload() async {
    final id = _workspaceId;
    if (id != null) await load(id);
  }
}