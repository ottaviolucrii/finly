import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';

enum TransactionMoveStatus { loading, ready, moving, moved, failure }

class TransactionMoveState extends Equatable {
  final TransactionMoveStatus status;

  /// The accounts the transaction can be moved to.
  final List<AccountEntity> targets;
  final Failure? failure;

  const TransactionMoveState({
    this.status = TransactionMoveStatus.loading,
    this.targets = const [],
    this.failure,
  });

  @override
  List<Object?> get props => [status, targets, failure];
}
