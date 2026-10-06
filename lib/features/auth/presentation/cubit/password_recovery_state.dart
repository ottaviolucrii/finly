import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';

enum PasswordRecoveryStatus {
  idle,
  sendingCode,
  codeSent,
  resetting,
  resetDone,
  failure,
}

class PasswordRecoveryState extends Equatable {
  final PasswordRecoveryStatus status;
  final Failure? failure;

  const PasswordRecoveryState({
    this.status = PasswordRecoveryStatus.idle,
    this.failure,
  });

  bool get isBusy =>
      status == PasswordRecoveryStatus.sendingCode ||
      status == PasswordRecoveryStatus.resetting;

  @override
  List<Object?> get props => [status, failure];
}