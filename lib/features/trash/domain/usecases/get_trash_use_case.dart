import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/trash/domain/entities/trashed_transaction.dart';
import 'package:finly/features/trash/domain/repositories/trash_repository.dart';

/// The trash of one workspace. Params: the workspace id.
class GetTrashUseCase implements UseCase<List<TrashedTransaction>, String> {
  /// How many deleted transactions the screen lists.
  static const limit = 100;

  final TrashRepository _repository;

  const GetTrashUseCase(this._repository);

  @override
  Future<Either<Failure, List<TrashedTransaction>>> call(
    String workspaceId,
  ) async {
    if (workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }
    return _repository.getTrash(workspaceId, limit: limit);
  }
}