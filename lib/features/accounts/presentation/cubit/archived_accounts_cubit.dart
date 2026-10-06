import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/usecases/get_archived_accounts_use_case.dart';
import 'package:finly/features/accounts/domain/usecases/restore_account_use_case.dart';
import 'package:finly/features/accounts/presentation/cubit/archived_accounts_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ArchivedAccountsCubit extends Cubit<ArchivedAccountsState> {
  final GetArchivedAccountsUseCase _getArchived;
  final RestoreAccountUseCase _restore;
  String? _workspaceId;

  ArchivedAccountsCubit({
    required GetArchivedAccountsUseCase getArchived,
    required RestoreAccountUseCase restore,
  })  : _getArchived = getArchived,
        _restore = restore,
        super(const ArchivedAccountsState());

  Future<void> load(String workspaceId) async {
    _workspaceId = workspaceId;
    // Keep the old list on screen while reloading, to avoid flicker.
    emit(ArchivedAccountsState(
      status: ArchivedAccountsStatus.loading,
      accounts: state.accounts,
    ));

    final result = await _getArchived(workspaceId);
    emit(result.fold<ArchivedAccountsState>(
      (failure) => ArchivedAccountsState(
        status: ArchivedAccountsStatus.failure,
        failure: failure,
      ),
      (accounts) => ArchivedAccountsState(
        status: ArchivedAccountsStatus.loaded,
        accounts: accounts,
      ),
    ));
  }

  Future<void> reload() async {
    final id = _workspaceId;
    if (id != null) await load(id);
  }

  /// Brings [account] back. Returns true when it worked, so the screen can
  /// reload the active accounts too.
  Future<bool> restore(AccountEntity account) async {
    final result = await _restore(account.id);

    return result.fold<Future<bool>>(
      (failure) async {
        emit(ArchivedAccountsState(
          status: ArchivedAccountsStatus.loaded,
          accounts: state.accounts,
          actionFailure: failure,
        ));
        return false;
      },
      (_) async {
        await reload();
        return true;
      },
    );
  }
}