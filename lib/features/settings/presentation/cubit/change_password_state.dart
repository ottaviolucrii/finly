import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';

enum ChangePasswordStatus { idle, submitting, success, failure }

class ChangePasswordState extends Equatable {
  final ChangePasswordStatus status;
  final Failure? failure;

  const ChangePasswordState({
    this.status = ChangePasswordStatus.idle,
    this.failure,
  });

  @override
  List<Object?> get props => [status, failure];
}