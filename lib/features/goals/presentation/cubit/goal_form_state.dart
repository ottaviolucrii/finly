import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';

enum GoalFormStatus {
  /// Reading the accounts the goal can follow.
  loading,

  /// The form can be filled in.
  ready,

  /// A save or an archive is running.
  saving,

  /// The goal was saved: the screen closes.
  saved,

  /// The goal was archived: the screen closes.
  archived,

  /// The accounts could not be read.
  loadFailed,
}

class GoalFormState extends Equatable {
  final GoalFormStatus status;

  /// The accounts a goal can follow: not credit cards.
  final List<AccountEntity> accounts;
  final Failure? loadFailure;

  /// Why the last save or archive failed (the form stays open).
  final Failure? saveFailure;

  const GoalFormState({
    this.status = GoalFormStatus.loading,
    this.accounts = const [],
    this.loadFailure,
    this.saveFailure,
  });

  @override
  List<Object?> get props => [status, accounts, loadFailure, saveFailure];
}
