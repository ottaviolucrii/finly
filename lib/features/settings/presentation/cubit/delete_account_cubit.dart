import 'package:finly/features/auth/domain/usecases/delete_account_use_case.dart';
import 'package:finly/features/settings/presentation/cubit/delete_account_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeleteAccountCubit extends Cubit<DeleteAccountState> {
  final DeleteAccountUseCase _deleteAccount;

  DeleteAccountCubit(this._deleteAccount) : super(const DeleteAccountState());

  Future<void> submit({
    required String password,
    required String confirmation,
  }) async {
    if (state.status == DeleteAccountStatus.submitting) return;

    emit(const DeleteAccountState(status: DeleteAccountStatus.submitting));
    final result = await _deleteAccount(
      DeleteAccountParams(password: password, confirmation: confirmation),
    );
    emit(result.fold<DeleteAccountState>(
      (failure) => DeleteAccountState(
        status: DeleteAccountStatus.failure,
        failure: failure,
      ),
      (_) => const DeleteAccountState(status: DeleteAccountStatus.success),
    ));
  }
}