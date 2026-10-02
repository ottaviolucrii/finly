import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';

enum AccountsStatus { initial, loading, loaded, failure }

class AccountsState extends Equatable {
  final AccountsStatus status;
  final List<AccountEntity> accounts;

  /// Why loading failed (shown full screen with a retry button).
  final Failure? failure;

  /// Why an action such as archiving failed (shown as a message).
  final Failure? actionFailure;

  const AccountsState({
    this.status = AccountsStatus.initial,
    this.accounts = const [],
    this.failure,
    this.actionFailure,
  });

  @override
  List<Object?> get props => [status, accounts, failure, actionFailure];
}