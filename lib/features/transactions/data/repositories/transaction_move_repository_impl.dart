import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/data/datasources/transaction_move_remote_data_source.dart';
import 'package:finly/features/transactions/domain/repositories/transaction_move_repository.dart';

class TransactionMoveRepositoryImpl implements TransactionMoveRepository {
  final TransactionMoveRemoteDataSource _remote;

  const TransactionMoveRepositoryImpl(this._remote);

  /// Exceptions become Left(Failure). Programming errors (Error) are mapped to
  /// an unknown_error failure and logged.
  @override
  Future<Either<Failure, void>> moveTransaction(
    String transactionId,
    String accountId,
  ) async {
    try {
      await _remote.moveTransaction(transactionId, accountId);
      return const Right<Failure, void>(null);
    } catch (e) {
      return Left<Failure, void>(ErrorMapper.toFailure(e));
    }
  }
}
