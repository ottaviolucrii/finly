import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/trash/domain/repositories/trash_repository.dart';

/// Brings a deleted transfer back. Params: the transfer id.
class RestoreTransferUseCase implements UseCase<void, String> {
  final TrashRepository _repository;

  const RestoreTransferUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(String transferId) async {
    if (transferId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_transfer'));
    }
    return _repository.restoreTransfer(transferId);
  }
}