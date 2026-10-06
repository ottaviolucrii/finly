import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';

enum ArchivedAccountsStatus { initial, loading, loaded, failure }

class ArchivedAccountsState extends Equatable {
  final ArchivedAccountsStatus status;
  final List<AccountEntity> accounts;

  /// Why loading failed.
  final Failure? failure;

  /// Why restoring failed (shown as a message).
  final Failure? actionFailure;

  const ArchivedAccountsState({
    this.status = ArchivedAccountsStatus.initial,
    this.accounts = const [],
    this.failure,
    this.actionFailure,
  });

  @override
  List<Object?> get props => [status, accounts, failure, actionFailure];
}