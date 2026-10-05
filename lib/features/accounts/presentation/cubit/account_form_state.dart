import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';

enum AccountFormStatus { idle, submitting, success, failure }

class AccountFormState extends Equatable {
  final AccountFormStatus status;
  final Failure? failure;
  final AccountEntity? account;

  const AccountFormState({
    this.status = AccountFormStatus.idle,
    this.failure,
    this.account,
  });

  @override
  List<Object?> get props => [status, failure, account];
}