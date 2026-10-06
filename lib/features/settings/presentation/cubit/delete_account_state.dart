import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';

enum DeleteAccountStatus { idle, submitting, success, failure }

class DeleteAccountState extends Equatable {
  final DeleteAccountStatus status;
  final Failure? failure;

  const DeleteAccountState({
    this.status = DeleteAccountStatus.idle,
    this.failure,
  });

  @override
  List<Object?> get props => [status, failure];
}