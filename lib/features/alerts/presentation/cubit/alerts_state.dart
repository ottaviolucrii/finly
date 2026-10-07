import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/alerts/domain/entities/app_alert.dart';

enum AlertsStatus { initial, loading, loaded, failure }

class AlertsState extends Equatable {
  final AlertsStatus status;

  /// The last alerts that loaded. They stay while reloading, and when a reload
  /// fails: an alert is a bonus, so a failure is not shown to the user.
  final List<AppAlert> alerts;
  final Failure? failure;

  const AlertsState({
    this.status = AlertsStatus.initial,
    this.alerts = const [],
    this.failure,
  });

  @override
  List<Object?> get props => [status, alerts, failure];
}