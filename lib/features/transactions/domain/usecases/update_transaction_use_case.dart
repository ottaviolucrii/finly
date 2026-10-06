import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/repositories/transaction_repository.dart';

class UpdateTransactionParams extends Equatable {
  final String transactionId;

  /// Null means "no category".
  final String? categoryId;
  final int amountCents;
  final String description;
  final DateTime occurredAt;
  final TransactionStatus status;

  const UpdateTransactionParams({
    required this.transactionId,
    this.categoryId,
    required this.amountCents,
    required this.description,
    required this.occurredAt,
    required this.status,
  });

  @override
  List<Object?> get props => [
        transactionId,
        categoryId,
        amountCents,
        description,
        occurredAt,
        status,
      ];
}

/// Changes what the database lets change: amount, category, description, date
/// and pending/posted. The type, the account and the currency never change.
class UpdateTransactionUseCase
    implements UseCase<TransactionEntity, UpdateTransactionParams> {
  final TransactionRepository _repository;

  const UpdateTransactionUseCase(this._repository);

  @override
  Future<Either<Failure, TransactionEntity>> call(
    UpdateTransactionParams params,
  ) async {
    if (params.transactionId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_transaction'));
    }
    // A transaction is pending or posted; "failed" is not something to set.
    if (params.status == TransactionStatus.failed) {
      return const Left(ValidationFailure('invalid_status'));
    }
    if (params.amountCents <= 0) {
      return const Left(ValidationFailure('invalid_amount'));
    }
    final description = params.description.trim();
    if (description.isEmpty || description.length > 200) {
      return const Left(ValidationFailure('invalid_description'));
    }

    return _repository.updateTransaction(
      transactionId: params.transactionId,
      categoryId: params.categoryId,
      amountCents: params.amountCents,
      description: description,
      occurredAt: params.occurredAt,
      status: params.status,
    );
  }
}