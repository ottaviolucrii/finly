import 'package:finly/features/accounts/domain/usecases/update_account_use_case.dart';
import 'package:finly/features/accounts/presentation/cubit/account_edit_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AccountEditCubit extends Cubit<AccountEditState> {
  final UpdateAccountUseCase _updateAccount;

  AccountEditCubit(this._updateAccount) : super(const AccountEditState());

  Future<void> submit({
    required String accountId,
    required String name,
    int? openingBalanceCents,
  }) async {
    if (state.status == AccountEditStatus.submitting) return;

    emit(const AccountEditState(status: AccountEditStatus.submitting));
    final result = await _updateAccount(
      UpdateAccountParams(
        accountId: accountId,
        name: name,
        openingBalanceCents: openingBalanceCents,
      ),
    );
    emit(result.fold<AccountEditState>(
      (failure) => AccountEditState(
        status: AccountEditStatus.failure,
        failure: failure,
      ),
      (_) => const AccountEditState(status: AccountEditStatus.success),
    ));
  }
}