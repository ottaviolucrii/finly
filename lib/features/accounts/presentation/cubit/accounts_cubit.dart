import 'package:finly/features/accounts/domain/usecases/archive_account_use_case.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/accounts/presentation/cubit/accounts_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AccountsCubit extends Cubit<AccountsState> {
  final GetAccountsUseCase _getAccounts;
  final ArchiveAccountUseCase _archiveAccount;
  String? _workspaceId;

  AccountsCubit(this._getAccounts, this._archiveAccount)
      : super(const AccountsState());

  Future<void> load(String workspaceId) async {
    _workspaceId = workspaceId;
    // Keep the old list on screen while reloading, to avoid flicker.
    emit(AccountsState(status: AccountsStatus.loading, accounts: state.accounts));

    final result = await _getAccounts(workspaceId);
    emit(result.fold<AccountsState>(
      (failure) =>
          AccountsState(status: AccountsStatus.failure, failure: failure),
      (accounts) =>
          AccountsState(status: AccountsStatus.loaded, accounts: accounts),
    ));
  }

  Future<void> reload() async {
    final id = _workspaceId;
    if (id != null) await load(id);
  }

  Future<void> archive(String accountId) async {
    final result = await _archiveAccount(accountId);
    result.fold(
      (failure) => emit(AccountsState(
        status: AccountsStatus.loaded,
        accounts: state.accounts,
        actionFailure: failure,
      )),
      (_) => emit(AccountsState(
        status: AccountsStatus.loaded,
        accounts:
            state.accounts.where((account) => account.id != accountId).toList(),
      )),
    );
  }
}