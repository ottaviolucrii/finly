import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/dashboard/domain/entities/monthly_flow_entry.dart';
import 'package:finly/features/dashboard/domain/usecases/get_month_totals_use_case.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum MonthTotalsStatus { initial, loading, loaded, failure }

class MonthTotalsState extends Equatable {
  final MonthTotalsStatus status;

  /// The month the totals are of (its first day).
  final DateTime? month;

  /// One entry per currency; empty when nothing happened in the month.
  final List<MonthlyFlowEntry> entries;
  final Failure? failure;

  const MonthTotalsState({
    this.status = MonthTotalsStatus.initial,
    this.month,
    this.entries = const [],
    this.failure,
  });

  /// The totals of the first currency (the one of most accounts), or null.
  MonthlyFlowEntry? get main => entries.isEmpty ? null : entries.first;

  @override
  List<Object?> get props => [status, month, entries, failure];
}

/// The totals of the month shown at the top of Extrato.
class MonthTotalsCubit extends Cubit<MonthTotalsState> {
  final GetMonthTotalsUseCase _getTotals;

  /// Counts the requests, so an old answer never replaces a newer one when
  /// the person moves between months quickly.
  int _request = 0;
  String? _workspaceId;

  MonthTotalsCubit(this._getTotals) : super(const MonthTotalsState());

  Future<void> load(String workspaceId, DateTime month) async {
    _workspaceId = workspaceId;
    final first = DateTime(month.year, month.month);
    final request = ++_request;

    // Keep the old numbers only when it is the same month (a reload).
    final sameMonth = state.month == first;
    emit(MonthTotalsState(
      status: MonthTotalsStatus.loading,
      month: first,
      entries: sameMonth ? state.entries : const [],
    ));

    final result = await _getTotals(
      GetMonthTotalsParams(workspaceId: workspaceId, month: first),
    );
    if (request != _request || isClosed) return;

    emit(result.fold(
      (failure) => MonthTotalsState(
        status: MonthTotalsStatus.failure,
        month: first,
        failure: failure,
      ),
      (entries) => MonthTotalsState(
        status: MonthTotalsStatus.loaded,
        month: first,
        entries: entries,
      ),
    ));
  }

  /// Reads the same month again (after something changed).
  Future<void> reload() async {
    final id = _workspaceId;
    final month = state.month;
    if (id != null && month != null) await load(id, month);
  }
}
