import 'package:finly/features/reports/domain/usecases/get_monthly_report_use_case.dart';
import 'package:finly/features/reports/presentation/cubit/reports_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReportsCubit extends Cubit<ReportsState> {
  final GetMonthlyReportUseCase _getReport;
  String? _workspaceId;

  /// Numbers each request, so that a slow answer for a month the user already
  /// left never replaces the one for the month on screen.
  int _request = 0;

  /// [clock] gives "now"; tests pass a fixed date.
  ReportsCubit(this._getReport, {DateTime Function()? clock})
      : super(_initial((clock ?? DateTime.now)()));

  static ReportsState _initial(DateTime now) {
    final month = DateTime(now.year, now.month);
    return ReportsState(month: month, currentMonth: month);
  }

  /// Shows the current month of [workspaceId].
  Future<void> load(String workspaceId) {
    _workspaceId = workspaceId;
    return _fetch(state.month);
  }

  Future<void> reload() => _fetch(state.month);

  Future<void> previousMonth() {
    return _fetch(DateTime(state.month.year, state.month.month - 1));
  }

  /// Does nothing on the current month.
  Future<void> nextMonth() async {
    if (!state.canGoNext) return;
    await _fetch(DateTime(state.month.year, state.month.month + 1));
  }

  Future<void> _fetch(DateTime month) async {
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;

    final request = ++_request;
    // Keep the old report on screen while the next one loads.
    emit(ReportsState(
      status: ReportsStatus.loading,
      month: month,
      currentMonth: state.currentMonth,
      report: state.report,
    ));

    final result = await _getReport(
      GetMonthlyReportParams(workspaceId: workspaceId, month: month),
    );
    if (request != _request) return;

    emit(result.fold<ReportsState>(
      (failure) => ReportsState(
        status: ReportsStatus.failure,
        month: month,
        currentMonth: state.currentMonth,
        report: state.report,
        failure: failure,
      ),
      (report) => ReportsState(
        status: ReportsStatus.loaded,
        month: month,
        currentMonth: state.currentMonth,
        report: report,
      ),
    ));
  }
}