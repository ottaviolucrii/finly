import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/recurring/domain/repositories/recurring_repository.dart';

/// Creates the pending transactions of the occurrences that are due. Returns
/// how many were created.
class GenerateRecurringUseCase implements UseCase<int, NoParams> {
  final RecurringRepository _repository;

  const GenerateRecurringUseCase(this._repository);

  @override
  Future<Either<Failure, int>> call(NoParams params) {
    return _repository.generateDue();
  }
}