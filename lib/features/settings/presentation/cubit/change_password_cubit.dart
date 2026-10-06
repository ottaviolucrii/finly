import 'package:finly/features/auth/domain/usecases/change_password_use_case.dart';
import 'package:finly/features/settings/presentation/cubit/change_password_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChangePasswordCubit extends Cubit<ChangePasswordState> {
  final ChangePasswordUseCase _changePassword;

  ChangePasswordCubit(this._changePassword) : super(const ChangePasswordState());

  Future<void> submit({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (state.status == ChangePasswordStatus.submitting) return;

    emit(const ChangePasswordState(status: ChangePasswordStatus.submitting));
    final result = await _changePassword(
      ChangePasswordParams(
        currentPassword: currentPassword,
        newPassword: newPassword,
      ),
    );
    emit(result.fold<ChangePasswordState>(
      (failure) => ChangePasswordState(
        status: ChangePasswordStatus.failure,
        failure: failure,
      ),
      (_) => const ChangePasswordState(status: ChangePasswordStatus.success),
    ));
  }
}