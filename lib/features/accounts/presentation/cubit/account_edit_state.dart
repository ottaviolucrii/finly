import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';

enum AccountEditStatus { idle, submitting, success, failure }

class AccountEditState extends Equatable {
  final AccountEditStatus status;
  final Failure? failure;

  const AccountEditState({this.status = AccountEditStatus.idle, this.failure});

  @override
  List<Object?> get props => [status, failure];
}