import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';

enum TransferFormStatus {
  /// Loading the accounts of the other workspace.
  loading,
  loadFailed,
  ready,
  submitting,
  success,
  failure,
}

class TransferFormState extends Equatable {
  final TransferFormStatus status;

  /// Accounts of the user's other workspace (empty when there is none).
  final List<AccountEntity> otherAccounts;
  final Failure? failure;

  const TransferFormState({
    this.status = TransferFormStatus.loading,
    this.otherAccounts = const [],
    this.failure,
  });

  @override
  List<Object?> get props => [status, otherAccounts, failure];
}