import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/transfers/domain/repositories/transfer_repository.dart';

/// Deletes both entries of a transfer. Params: the transfer id.
class DeleteTransferUseCase implements UseCase<void, String> {
  final TransferRepository _repository;

  const DeleteTransferUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(String transferId) async {
    if (transferId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_transfer'));
    }
    return _repository.deleteTransfer(transferId);
  }
}