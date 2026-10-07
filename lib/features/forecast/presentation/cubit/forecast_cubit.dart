import 'package:finly/features/forecast/domain/usecases/get_forecast_use_case.dart';
import 'package:finly/features/forecast/presentation/cubit/forecast_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ForecastCubit extends Cubit<ForecastState> {
  final GetForecastUseCase _getForecast;
  final DateTime Function() _clock;
  String? _workspaceId;

  /// [clock] gives "now"; tests pass a fixed date.
  ForecastCubit(this._getForecast, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        super(const ForecastState());

  Future<void> load(String workspaceId) {
    _workspaceId = workspaceId;
    return reload();
  }

  Future<void> reload() async {
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;

    emit(ForecastState(
      status: ForecastStatus.loading,
      forecasts: state.forecasts,
      today: state.today,
    ));

    final now = _clock();
    final result = await _getForecast(
      GetForecastParams(workspaceId: workspaceId, today: now),
    );

    emit(result.fold<ForecastState>(
      (failure) => ForecastState(
        status: ForecastStatus.failure,
        forecasts: state.forecasts,
        today: state.today,
        failure: failure,
      ),
      (forecasts) => ForecastState(
        status: ForecastStatus.loaded,
        forecasts: forecasts,
        today: DateTime(now.year, now.month, now.day),
      ),
    ));
  }
}
