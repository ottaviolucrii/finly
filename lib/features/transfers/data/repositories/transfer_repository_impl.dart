import 'package:dartz/dartz.dart';
import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transfers/data/datasources/transfer_remote_data_source.dart';
import 'package:finly/features/transfers/domain/entities/transfer_kind.dart';
import 'package:finly/features/transfers/domain/repositories/transfer_repository.dart';

class TransferRepositoryImpl implements TransferRepository {
  final TransferRemoteDataSource _remote;

  const TransferRepositoryImpl(this._remote);

  @override
  Future<Either<Failure, String>> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required int amountCents,
    int? toAmountCents,
    required String description,
    required DateTime occurredAt,
    required TransferKind kind,
  }) {
    return _guard<String>(
      () => _remote.createTransfer(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amountCents: amountCents,
        toAmountCents: toAmountCents,
        description: description,
        occurredAt: occurredAt,
        kind: kind,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> deleteTransfer(String transferId) {
    return _guard<void>(() => _remote.deleteTransfer(transferId));
  }

  /// Runs [action]; exceptions become Left(Failure). Programming errors
  /// (Error, not Exception) are not caught on purpose.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right<Failure, T>(await action());
    } on Exception catch (e) {
      return Left<Failure, T>(ErrorMapper.toFailure(e));
    }
  }
}