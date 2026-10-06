import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/reports/domain/entities/monthly_report.dart';

enum ReportsStatus { initial, loading, loaded, failure }

class ReportsState extends Equatable {
  final ReportsStatus status;

  /// The month being shown (first day).
  final DateTime month;

  /// The current month (first day): the report cannot go past it.
  final DateTime currentMonth;

  /// The last report that loaded. It stays on screen while another loads.
  final MonthlyReport? report;
  final Failure? failure;

  const ReportsState({
    this.status = ReportsStatus.initial,
    required this.month,
    required this.currentMonth,
    this.report,
    this.failure,
  });

  bool get canGoNext => month.isBefore(currentMonth);

  @override
  List<Object?> get props => [status, month, currentMonth, report, failure];
}