import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/forecast/domain/entities/forecast_items.dart';

enum ForecastStatus { initial, loading, loaded, failure }

class ForecastState extends Equatable {
  final ForecastStatus status;

  /// One forecast per currency, 90 days each. They stay on screen while a
  /// reload runs, and when it fails.
  final List<Forecast> forecasts;

  /// The day the forecasts start from.
  final DateTime? today;
  final Failure? failure;

  const ForecastState({
    this.status = ForecastStatus.initial,
    this.forecasts = const [],
    this.today,
    this.failure,
  });

  @override
  List<Object?> get props => [status, forecasts, today, failure];
}
