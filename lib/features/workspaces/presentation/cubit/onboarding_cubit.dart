import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/workspaces/domain/usecases/create_workspace_use_case.dart';
import 'package:finly/features/workspaces/presentation/cubit/onboarding_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  final CreateWorkspaceUseCase _createWorkspace;

  OnboardingCubit(this._createWorkspace) : super(const OnboardingState());

  void selectType(WorkspaceType type) => emit(OnboardingState(type: type));

  void backToTypes() {
    if (state.status == OnboardingStatus.submitting) return;
    emit(const OnboardingState());
  }

  Future<void> submit({required String name, required String taxId}) async {
    final type = state.type;
    if (type == null || state.status == OnboardingStatus.submitting) return;

    emit(OnboardingState(type: type, status: OnboardingStatus.submitting));
    final result = await _createWorkspace(
      CreateWorkspaceParams(name: name, type: type, taxId: taxId),
    );
    emit(result.fold<OnboardingState>(
      (failure) => OnboardingState(
        type: type,
        status: OnboardingStatus.failure,
        failure: failure,
      ),
      (workspace) => OnboardingState(
        type: type,
        status: OnboardingStatus.success,
        workspace: workspace,
      ),
    ));
  }
}