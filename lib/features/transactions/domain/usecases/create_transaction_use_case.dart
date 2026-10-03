import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/domain/repositories/transaction_repository.dart';

class CreateTransactionParams extends Equatable {
  final String workspaceId;
  final String accountId;
  final String? categoryId;
  final TransactionType type;
  final TransactionStatus status;
  final int amountCents;
  final String currency;
  final String description;
  final DateTime occurredAt;

  const CreateTransactionParams({
    required this.workspaceId,
    required this.accountId,
    this.categoryId,
    required this.type,
    required this.status,
    required this.amountCents,
    required this.currency,
    required this.description,
    required this.occurredAt,
  });

  @override
  List<Object?> get props => [
        workspaceId,
        accountId,
        categoryId,
        type,
        status,
        amountCents,
        currency,
        description,
        occurredAt,
      ];
}

class CreateTransactionUseCase
    implements UseCase<TransactionEntity, CreateTransactionParams> {
  final TransactionRepository _repository;

  const CreateTransactionUseCase(this._repository);

  @override
  Future<Either<Failure, TransactionEntity>> call(
    CreateTransactionParams params,
  ) async {
    if (params.accountId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_account'));
    }
    // Transfers are two linked legs, created by their own flow.
    if (params.type.isTransfer) {
      return const Left(ValidationFailure('invalid_transaction_type'));
    }
    // A new transaction is expected (pending) or confirmed (posted).
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

    return _repository.createTransaction(
      workspaceId: params.workspaceId,
      accountId: params.accountId,
      categoryId: params.categoryId,
      type: params.type,
      status: params.status,
      amountCents: params.amountCents,
      currency: params.currency,
      description: description,
      occurredAt: params.occurredAt,
    );
  }
}