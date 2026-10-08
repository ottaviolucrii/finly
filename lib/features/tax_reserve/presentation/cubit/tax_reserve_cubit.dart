import 'package:finly/features/tax_reserve/domain/usecases/get_tax_reserve_use_case.dart';
import 'package:finly/features/tax_reserve/domain/usecases/save_tax_reserve_percent_use_case.dart';
import 'package:finly/features/tax_reserve/presentation/cubit/tax_reserve_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TaxReserveCubit extends Cubit<TaxReserveState> {
  final GetTaxReserveUseCase _getTaxReserve;
  final SaveTaxReservePercentUseCase _savePercent;
  String? _workspaceId;

  /// Numbers each request, so that a slow answer for a month the person already
  /// left never replaces the one for the month on screen.
  int _request = 0;

  /// [clock] gives "now"; tests pass a fixed date.
  TaxReserveCubit({
    required GetTaxReserveUseCase getTaxReserve,
    required SaveTaxReservePercentUseCase savePercent,
    DateTime Function()? clock,
  })  : _getTaxReserve = getTaxReserve,
        _savePercent = savePercent,
        super(_initial((clock ?? DateTime.now)()));

  static TaxReserveState _initial(DateTime now) {
    final month = DateTime(now.year, now.month);
    return TaxReserveState(month: month, currentMonth: month);
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
    // Keep the old numbers on screen while the next month loads.
    emit(TaxReserveState(
      status: TaxReserveStatus.loading,
      month: month,
      currentMonth: state.currentMonth,
      data: state.data,
    ));

    final result = await _getTaxReserve(
      GetTaxReserveParams(workspaceId: workspaceId, month: month),
    );
    if (isClosed || request != _request) return;

    emit(result.fold<TaxReserveState>(
      (failure) => TaxReserveState(
        status: TaxReserveStatus.failure,
        month: month,
        currentMonth: state.currentMonth,
        data: state.data,
        failure: failure,
      ),
      (data) => TaxReserveState(
        status: TaxReserveStatus.loaded,
        month: month,
        currentMonth: state.currentMonth,
        data: data,
      ),
    ));
  }

  /// Saves the percentage and shows it at once. If saving fails the old one
  /// comes back and [TaxReserveState.saveFailure] says why.
  Future<void> savePercent(int percentBps) async {
    final workspaceId = _workspaceId;
    final current = state.data;
    if (workspaceId == null || current == null || state.saving) return;

    emit(TaxReserveState(
      status: state.status,
      month: state.month,
      currentMonth: state.currentMonth,
      data: current.withPercent(percentBps),
      saving: true,
    ));

    final result = await _savePercent(
      SaveTaxReservePercentParams(workspaceId: workspaceId, percentBps: percentBps),
    );
    if (isClosed) return;

    emit(result.fold<TaxReserveState>(
      (failure) => TaxReserveState(
        status: state.status,
        month: state.month,
        currentMonth: state.currentMonth,
        data: current,
        saveFailure: failure,
      ),
      (_) => TaxReserveState(
        status: state.status,
        month: state.month,
        currentMonth: state.currentMonth,
        data: current.withPercent(percentBps),
      ),
    ));
  }
}
