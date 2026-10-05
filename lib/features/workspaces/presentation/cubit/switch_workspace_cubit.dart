import 'dart:async';

import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/domain/usecases/switch_workspace_use_case.dart';
import 'package:finly/features/workspaces/presentation/cubit/switch_workspace_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SwitchWorkspaceCubit extends Cubit<SwitchWorkspaceState> {
  final SwitchWorkspaceUseCase _switchWorkspace;
  final Duration _timeout;

  SwitchWorkspaceCubit(
    this._switchWorkspace, {
    Duration timeout = const Duration(seconds: 20),
  })  : _timeout = timeout,
        super(const SwitchWorkspaceState());

  /// Never leaves the cubit stuck in "switching": a slow or failed call ends
  /// in a failure after [_timeout], so the switch control always comes back.
  Future<void> switchTo(String workspaceId) async {
    if (state.status == SwitchWorkspaceStatus.switching) return;

    emit(const SwitchWorkspaceState(status: SwitchWorkspaceStatus.switching));
    SwitchWorkspaceState outcome;
    try {
      final result = await _switchWorkspace(
        SwitchWorkspaceParams(workspaceId: workspaceId),
      ).timeout(_timeout);
      outcome = result.fold<SwitchWorkspaceState>(
        (failure) => SwitchWorkspaceState(
          status: SwitchWorkspaceStatus.failure,
          failure: failure,
        ),
        (user) => SwitchWorkspaceState(
          status: SwitchWorkspaceStatus.success,
          user: user,
        ),
      );
    } on TimeoutException {
      outcome = const SwitchWorkspaceState(
        status: SwitchWorkspaceStatus.failure,
        failure: NetworkFailure('network_error'),
      );
    } catch (_) {
      outcome = const SwitchWorkspaceState(
        status: SwitchWorkspaceStatus.failure,
        failure: RuleFailure('unexpected_error'),
      );
    }

    if (!isClosed) emit(outcome);
  }
}