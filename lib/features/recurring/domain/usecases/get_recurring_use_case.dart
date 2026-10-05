import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/recurring/domain/entities/recurring_entity.dart';
import 'package:finly/features/recurring/domain/repositories/recurring_repository.dart';

/// Params: the workspace id.
class GetRecurringUseCase implements UseCase<List<RecurringEntity>, String> {
  final RecurringRepository _repository;

  const GetRecurringUseCase(this._repository);

  @override
  Future<Either<Failure, List<RecurringEntity>>> call(
    String workspaceId,
  ) async {
    if (workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }
    return _repository.getRecurring(workspaceId);
  }
}