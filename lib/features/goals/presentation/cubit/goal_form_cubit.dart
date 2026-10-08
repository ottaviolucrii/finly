import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/goals/domain/usecases/archive_goal_use_case.dart';
import 'package:finly/features/goals/domain/usecases/save_goal_use_case.dart';
import 'package:finly/features/goals/presentation/cubit/goal_form_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The form that creates, changes and archives a goal.
class GoalFormCubit extends Cubit<GoalFormState> {
  final GetAccountsUseCase _getAccounts;
  final SaveGoalUseCase _saveGoal;
  final ArchiveGoalUseCase _archiveGoal;

  GoalFormCubit({
    required GetAccountsUseCase getAccounts,
    required SaveGoalUseCase saveGoal,
    required ArchiveGoalUseCase archiveGoal,
  })  : _getAccounts = getAccounts,
        _saveGoal = saveGoal,
        _archiveGoal = archiveGoal,
        super(const GoalFormState());

  /// Reads the accounts of [workspaceId]. A goal can follow any of them except a
  /// credit card, whose balance is a debt.
  Future<void> load(String workspaceId) async {
    emit(const GoalFormState());
    final result = await _getAccounts(workspaceId);
    if (isClosed) return;

    emit(result.fold<GoalFormState>(
      (failure) => GoalFormState(status: GoalFormStatus.loadFailed, loadFailure: failure),
      (accounts) => GoalFormState(
        status: GoalFormStatus.ready,
        accounts: [
          for (final account in accounts)
            if (account.type != AccountType.creditCard) account,
        ],
      ),
    ));
  }

  Future<void> save(SaveGoalParams params) async {
    if (state.status == GoalFormStatus.saving) return;

    final accounts = state.accounts;
    emit(GoalFormState(status: GoalFormStatus.saving, accounts: accounts));

    final result = await _saveGoal(params);
    if (isClosed) return;

    emit(result.fold<GoalFormState>(
      (failure) => GoalFormState(
        status: GoalFormStatus.ready,
        accounts: accounts,
        saveFailure: failure,
      ),
      (_) => GoalFormState(status: GoalFormStatus.saved, accounts: accounts),
    ));
  }

  Future<void> archive(String goalId) async {
    if (state.status == GoalFormStatus.saving) return;

    final accounts = state.accounts;
    emit(GoalFormState(status: GoalFormStatus.saving, accounts: accounts));

    final result = await _archiveGoal(goalId);
    if (isClosed) return;

    emit(result.fold<GoalFormState>(
      (failure) => GoalFormState(
        status: GoalFormStatus.ready,
        accounts: accounts,
        saveFailure: failure,
      ),
      (_) => GoalFormState(status: GoalFormStatus.archived, accounts: accounts),
    ));
  }
}
