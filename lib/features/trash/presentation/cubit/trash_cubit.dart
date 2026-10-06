import 'package:finly/features/transactions/domain/usecases/restore_transaction_use_case.dart';
import 'package:finly/features/trash/domain/entities/trashed_transaction.dart';
import 'package:finly/features/trash/domain/usecases/get_trash_use_case.dart';
import 'package:finly/features/trash/presentation/cubit/trash_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TrashCubit extends Cubit<TrashState> {
  final GetTrashUseCase _getTrash;
  final RestoreTransactionUseCase _restoreTransaction;
  String? _workspaceId;

  TrashCubit({
    required GetTrashUseCase getTrash,
    required RestoreTransactionUseCase restoreTransaction,
  })  : _getTrash = getTrash,
        _restoreTransaction = restoreTransaction,
        super(const TrashState());

  Future<void> load(String workspaceId) async {
    _workspaceId = workspaceId;
    // Keep the old list on screen while reloading, to avoid flicker.
    emit(TrashState(status: TrashStatus.loading, items: state.items));

    final result = await _getTrash(workspaceId);
    emit(result.fold<TrashState>(
      (failure) => TrashState(
        status: TrashStatus.failure,
        items: state.items,
        failure: failure,
      ),
      (items) => TrashState(status: TrashStatus.loaded, items: items),
    ));
  }

  Future<void> reload() async {
    final id = _workspaceId;
    if (id != null) await load(id);
  }

  /// Brings a transaction back. The database refuses, for example, a purchase
  /// on a card invoice that was already paid; then the list stays as it is.
  Future<void> restore(TrashedTransaction item) async {
    final result = await _restoreTransaction(item.transaction.id);

    result.fold(
      (failure) => emit(TrashState(
        status: TrashStatus.loaded,
        items: state.items,
        actionFailure: failure,
      )),
      (_) => emit(TrashState(
        status: TrashStatus.loaded,
        items: state.items
            .where((i) => i.transaction.id != item.transaction.id)
            .toList(),
        restored: item.transaction,
      )),
    );
  }
}