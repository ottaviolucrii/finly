import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/dashboard/domain/entities/dashboard_charts.dart';

enum DashboardChartsStatus { initial, loading, loaded, failure }

class DashboardChartsState extends Equatable {
  final DashboardChartsStatus status;

  /// The last charts that loaded. They stay on screen while reloading, and
  /// when a reload fails.
  final DashboardCharts? charts;
  final Failure? failure;

  const DashboardChartsState({
    this.status = DashboardChartsStatus.initial,
    this.charts,
    this.failure,
  });

  @override
  List<Object?> get props => [status, charts, failure];
}