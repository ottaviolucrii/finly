import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/domain/usecases/restore_transaction_use_case.dart';
import 'package:finly/features/trash/domain/entities/trashed_transaction.dart';
import 'package:finly/features/trash/domain/entities/trashed_transfer.dart';
import 'package:finly/features/trash/domain/usecases/get_trash_use_case.dart';
import 'package:finly/features/trash/domain/usecases/get_trashed_transfers_use_case.dart';
import 'package:finly/features/trash/domain/usecases/restore_transfer_use_case.dart';
import 'package:finly/features/trash/presentation/cubit/trash_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TrashCubit extends Cubit<TrashState> {
  final GetTrashUseCase _getTrash;
  final GetTrashedTransfersUseCase _getTransfers;
  final RestoreTransactionUseCase _restoreTransaction;
  final RestoreTransferUseCase _restoreTransfer;
  String? _workspaceId;

  TrashCubit({
    required GetTrashUseCase getTrash,
    required GetTrashedTransfersUseCase getTransfers,
    required RestoreTransactionUseCase restoreTransaction,
    required RestoreTransferUseCase restoreTransfer,
  })  : _getTrash = getTrash,
        _getTransfers = getTransfers,
        _restoreTransaction = restoreTransaction,
        _restoreTransfer = restoreTransfer,
        super(const TrashState());

  Future<void> load(String workspaceId) async {
    _workspaceId = workspaceId;
    // Keep the old list on screen while reloading, to avoid flicker.
    emit(TrashState(
      status: TrashStatus.loading,
      items: state.items,
      transfers: state.transfers,
    ));

    final (itemsResult, transfersResult) =
        await (_getTrash(workspaceId), _getTransfers(workspaceId)).wait;

    Failure? failure;
    var items = const <TrashedTransaction>[];
    var transfers = const <TrashedTransfer>[];
    itemsResult.fold((f) {
      failure ??= f;
    }, (value) {
      items = value;
    });
    transfersResult.fold((f) {
      failure ??= f;
    }, (value) {
      transfers = value;
    });

    final problem = failure;
    if (problem != null) {
      emit(TrashState(
        status: TrashStatus.failure,
        items: state.items,
        transfers: state.transfers,
        failure: problem,
      ));
      return;
    }
    emit(TrashState(
      status: TrashStatus.loaded,
      items: items,
      transfers: transfers,
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
        transfers: state.transfers,
        actionFailure: failure,
      )),
      (_) => emit(TrashState(
        status: TrashStatus.loaded,
        items: state.items
            .where((i) => i.transaction.id != item.transaction.id)
            .toList(),
        transfers: state.transfers,
        restored: item.transaction,
      )),
    );
  }

  /// Brings a transfer back, both legs together. The database refuses a card
  /// invoice payment; then the list stays as it is.
  Future<void> restoreTransfer(TrashedTransfer item) async {
    final result = await _restoreTransfer(item.transferId);

    result.fold(
      (failure) => emit(TrashState(
        status: TrashStatus.loaded,
        items: state.items,
        transfers: state.transfers,
        actionFailure: failure,
      )),
      (_) => emit(TrashState(
        status: TrashStatus.loaded,
        items: state.items,
        transfers: state.transfers
            .where((t) => t.transferId != item.transferId)
            .toList(),
        restoredTransfer: item,
      )),
    );
  }
}