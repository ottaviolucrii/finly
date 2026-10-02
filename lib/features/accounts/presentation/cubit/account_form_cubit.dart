import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/usecases/create_account_use_case.dart';
import 'package:finly/features/accounts/presentation/cubit/account_form_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AccountFormCubit extends Cubit<AccountFormState> {
  final CreateAccountUseCase _createAccount;

  AccountFormCubit(this._createAccount) : super(const AccountFormState());

  Future<void> submit({
    required String workspaceId,
    required String name,
    required AccountType type,
    required String currency,
    required int openingBalanceCents,
  }) async {
    if (state.status == AccountFormStatus.submitting) return;

    emit(const AccountFormState(status: AccountFormStatus.submitting));
    final result = await _createAccount(
      CreateAccountParams(
        workspaceId: workspaceId,
        name: name,
        type: type,
        currency: currency,
        openingBalanceCents: openingBalanceCents,
      ),
    );
    emit(result.fold<AccountFormState>(
      (failure) => AccountFormState(
        status: AccountFormStatus.failure,
        failure: failure,
      ),
      (account) => AccountFormState(
        status: AccountFormStatus.success,
        account: account,
      ),
    ));
  }
}