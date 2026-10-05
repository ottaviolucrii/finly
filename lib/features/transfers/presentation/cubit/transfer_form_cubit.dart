import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/transfers/domain/entities/transfer_kind.dart';
import 'package:finly/features/transfers/domain/usecases/create_transfer_use_case.dart';
import 'package:finly/features/transfers/presentation/cubit/transfer_form_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TransferFormCubit extends Cubit<TransferFormState> {
  final GetAccountsUseCase _getAccounts;
  final CreateTransferUseCase _createTransfer;

  TransferFormCubit(this._getAccounts, this._createTransfer)
      : super(const TransferFormState());

  /// Loads the accounts of the other workspace, needed for transfers between
  /// workspaces. Pass null when the user has only one workspace.
  Future<void> loadOtherAccounts(String? otherWorkspaceId) async {
    if (otherWorkspaceId == null) {
      emit(const TransferFormState(status: TransferFormStatus.ready));
      return;
    }

    emit(const TransferFormState(status: TransferFormStatus.loading));
    final result = await _getAccounts(otherWorkspaceId);
    emit(result.fold<TransferFormState>(
      (failure) => TransferFormState(
        status: TransferFormStatus.loadFailed,
        failure: failure,
      ),
      (accounts) => TransferFormState(
        status: TransferFormStatus.ready,
        otherAccounts: accounts,
      ),
    ));
  }

  Future<void> submit({
    required String fromAccountId,
    required String toAccountId,
    required String fromCurrency,
    required String toCurrency,
    required int amountCents,
    int? toAmountCents,
    required String description,
    required DateTime occurredAt,
    required TransferKind kind,
  }) async {
    if (state.status == TransferFormStatus.submitting) return;

    emit(TransferFormState(
      status: TransferFormStatus.submitting,
      otherAccounts: state.otherAccounts,
    ));
    final result = await _createTransfer(
      CreateTransferParams(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
        amountCents: amountCents,
        toAmountCents: toAmountCents,
        description: description,
        occurredAt: occurredAt,
        kind: kind,
      ),
    );
    emit(result.fold<TransferFormState>(
      (failure) => TransferFormState(
        status: TransferFormStatus.failure,
        otherAccounts: state.otherAccounts,
        failure: failure,
      ),
      (_) => TransferFormState(
        status: TransferFormStatus.success,
        otherAccounts: state.otherAccounts,
      ),
    ));
  }
}