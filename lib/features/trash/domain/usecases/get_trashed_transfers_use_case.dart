import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/trash/domain/entities/trashed_transfer.dart';
import 'package:finly/features/trash/domain/repositories/trash_repository.dart';

/// The deleted transfers of one workspace. Params: the workspace id.
class GetTrashedTransfersUseCase
    implements UseCase<List<TrashedTransfer>, String> {
  /// How many deleted transfers the screen lists.
  static const limit = 100;

  final TrashRepository _repository;

  const GetTrashedTransfersUseCase(this._repository);

  @override
  Future<Either<Failure, List<TrashedTransfer>>> call(String workspaceId) async {
    if (workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }
    return _repository.getTrashedTransfers(workspaceId, limit: limit);
  }
}