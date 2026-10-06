import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_filter.dart';
import 'package:finly/features/transactions/domain/repositories/transaction_repository.dart';

class GetTransactionsParams extends Equatable {
  final String workspaceId;

  /// Rows per page.
  final int limit;

  /// Rows to skip (the ones already loaded).
  final int offset;
  final TransactionFilter filter;

  const GetTransactionsParams({
    required this.workspaceId,
    this.limit = 20,
    this.offset = 0,
    this.filter = const TransactionFilter(),
  });

  @override
  List<Object?> get props => [workspaceId, limit, offset, filter];
}

/// One page of transactions, newest first.
class GetTransactionsUseCase
    implements UseCase<List<TransactionEntity>, GetTransactionsParams> {
  final TransactionRepository _repository;

  const GetTransactionsUseCase(this._repository);

  @override
  Future<Either<Failure, List<TransactionEntity>>> call(
    GetTransactionsParams params,
  ) async {
    if (params.workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }
    if (params.limit < 1 || params.limit > 100 || params.offset < 0) {
      return const Left(ValidationFailure('invalid_page'));
    }
    return _repository.getTransactions(
      params.workspaceId,
      limit: params.limit,
      offset: params.offset,
      filter: params.filter,
    );
  }
}