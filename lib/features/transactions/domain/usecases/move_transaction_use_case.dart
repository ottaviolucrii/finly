import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/transactions/domain/repositories/transaction_move_repository.dart';

class MoveTransactionParams extends Equatable {
  final String transactionId;
  final String accountId;

  const MoveTransactionParams({
    required this.transactionId,
    required this.accountId,
  });

  @override
  List<Object?> get props => [transactionId, accountId];
}

/// Moves a transaction to another account of the same workspace.
class MoveTransactionUseCase implements UseCase<void, MoveTransactionParams> {
  final TransactionMoveRepository _repository;

  const MoveTransactionUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(MoveTransactionParams params) async {
    if (params.transactionId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_transaction'));
    }
    if (params.accountId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_account'));
    }
    return _repository.moveTransaction(params.transactionId, params.accountId);
  }
}
