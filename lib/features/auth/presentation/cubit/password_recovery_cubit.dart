import 'package:finly/features/auth/domain/usecases/request_password_reset_use_case.dart';
import 'package:finly/features/auth/domain/usecases/reset_password_use_case.dart';
import 'package:finly/features/auth/presentation/cubit/password_recovery_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PasswordRecoveryCubit extends Cubit<PasswordRecoveryState> {
  final RequestPasswordResetUseCase _requestReset;
  final ResetPasswordUseCase _resetPassword;

  PasswordRecoveryCubit({
    required RequestPasswordResetUseCase requestReset,
    required ResetPasswordUseCase resetPassword,
  })  : _requestReset = requestReset,
        _resetPassword = resetPassword,
        super(const PasswordRecoveryState());

  /// Sends (or sends again) the code by e-mail.
  Future<void> requestCode(String email) async {
    if (state.isBusy) return;

    emit(const PasswordRecoveryState(status: PasswordRecoveryStatus.sendingCode));
    final result = await _requestReset(email);
    emit(result.fold<PasswordRecoveryState>(
      (failure) => PasswordRecoveryState(
        status: PasswordRecoveryStatus.failure,
        failure: failure,
      ),
      (_) => const PasswordRecoveryState(status: PasswordRecoveryStatus.codeSent),
    ));
  }

  /// Checks the code and sets the new password.
  Future<void> reset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    if (state.isBusy) return;

    emit(const PasswordRecoveryState(status: PasswordRecoveryStatus.resetting));
    final result = await _resetPassword(
      ResetPasswordParams(email: email, code: code, newPassword: newPassword),
    );
    emit(result.fold<PasswordRecoveryState>(
      (failure) => PasswordRecoveryState(
        status: PasswordRecoveryStatus.failure,
        failure: failure,
      ),
      (_) => const PasswordRecoveryState(status: PasswordRecoveryStatus.resetDone),
    ));
  }
}