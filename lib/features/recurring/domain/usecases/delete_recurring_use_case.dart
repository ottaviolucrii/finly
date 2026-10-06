import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/recurring/domain/repositories/recurring_repository.dart';

/// Deletes a recurring item and its pending occurrences. What was already
/// confirmed stays in the history. Params: the item id.
class DeleteRecurringUseCase implements UseCase<void, String> {
  final RecurringRepository _repository;

  const DeleteRecurringUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(String id) async {
    if (id.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_recurring'));
    }
    return _repository.deleteRecurring(id);
  }
}