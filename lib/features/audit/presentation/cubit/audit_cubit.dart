import 'package:finly/features/audit/domain/audit_filter.dart';
import 'package:finly/features/audit/domain/usecases/get_audit_history_use_case.dart';
import 'package:finly/features/audit/presentation/cubit/audit_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuditCubit extends Cubit<AuditState> {
  final GetAuditHistoryUseCase _getHistory;
  String? _workspaceId;

  /// Numbers each request, so that a slow answer for a filter the person already
  /// left never replaces the list on screen.
  int _request = 0;

  AuditCubit(this._getHistory) : super(const AuditState());

  /// Shows the first page of the history of [workspaceId].
  Future<void> load(String workspaceId) {
    _workspaceId = workspaceId;
    return _first(state.filter);
  }

  Future<void> refresh() => _first(state.filter);

  Future<void> setFilter(AuditFilter filter) {
    if (filter == state.filter && state.status == AuditStatus.loaded) {
      return Future.value();
    }
    return _first(filter);
  }

  Future<void> _first(AuditFilter filter) async {
    final workspaceId = _workspaceId;
    if (workspaceId == null) return;

    final request = ++_request;
    // The old list stays while a refresh runs; another filter starts empty.
    emit(AuditState(
      status: AuditStatus.loading,
      filter: filter,
      items: filter == state.filter ? state.items : const [],
    ));

    final result = await _getHistory(
      GetAuditHistoryParams(workspaceId: workspaceId, filter: filter),
    );
    if (isClosed || request != _request) return;

    emit(result.fold<AuditState>(
      (failure) => AuditState(
        status: AuditStatus.failure,
        filter: filter,
        items: state.items,
        failure: failure,
      ),
      (page) => AuditState(
        status: AuditStatus.loaded,
        filter: filter,
        items: page.items,
        hasMore: page.hasMore,
      ),
    ));
  }

  /// Reads the next page and adds it below what is on screen.
  Future<void> loadMore() async {
    final workspaceId = _workspaceId;
    if (workspaceId == null || !state.hasMore || state.loadingMore) return;
    if (state.status != AuditStatus.loaded) return;

    final request = ++_request;
    final before = state;
    emit(AuditState(
      status: AuditStatus.loaded,
      filter: before.filter,
      items: before.items,
      hasMore: before.hasMore,
      loadingMore: true,
    ));

    final result = await _getHistory(
      GetAuditHistoryParams(
        workspaceId: workspaceId,
        offset: before.items.length,
        filter: before.filter,
      ),
    );
    if (isClosed || request != _request) return;

    emit(result.fold<AuditState>(
      // A failure on a later page keeps what is shown, and says so.
      (failure) => AuditState(
        status: AuditStatus.loaded,
        filter: before.filter,
        items: before.items,
        hasMore: before.hasMore,
        failure: failure,
      ),
      (page) => AuditState(
        status: AuditStatus.loaded,
        filter: before.filter,
        items: [...before.items, ...page.items],
        hasMore: page.hasMore,
      ),
    ));
  }
}
