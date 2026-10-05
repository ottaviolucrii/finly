import 'package:finly/features/auth/domain/usecases/switch_workspace_use_case.dart';
import 'package:finly/features/workspaces/presentation/cubit/switch_workspace_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SwitchWorkspaceCubit extends Cubit<SwitchWorkspaceState> {
  final SwitchWorkspaceUseCase _switchWorkspace;

  SwitchWorkspaceCubit(this._switchWorkspace)
      : super(const SwitchWorkspaceState());

  Future<void> switchTo(String workspaceId) async {
    if (state.status == SwitchWorkspaceStatus.switching) return;

    emit(const SwitchWorkspaceState(status: SwitchWorkspaceStatus.switching));
    final result = await _switchWorkspace(
      SwitchWorkspaceParams(workspaceId: workspaceId),
    );
    emit(result.fold<SwitchWorkspaceState>(
      (failure) => SwitchWorkspaceState(
        status: SwitchWorkspaceStatus.failure,
        failure: failure,
      ),
      (_) => const SwitchWorkspaceState(status: SwitchWorkspaceStatus.success),
    ));
  }
}