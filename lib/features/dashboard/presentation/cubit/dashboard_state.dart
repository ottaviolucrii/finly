import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/dashboard/domain/entities/dashboard_data.dart';

enum DashboardStatus { initial, loading, loaded, failure }

class DashboardState extends Equatable {
  final DashboardStatus status;

  /// The last data that loaded. It stays on screen while reloading, and when
  /// a reload fails.
  final DashboardData? data;
  final Failure? failure;

  const DashboardState({
    this.status = DashboardStatus.initial,
    this.data,
    this.failure,
  });

  @override
  List<Object?> get props => [status, data, failure];
}