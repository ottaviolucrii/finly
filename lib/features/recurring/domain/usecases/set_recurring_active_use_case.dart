import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/recurring/domain/repositories/recurring_repository.dart';

class SetRecurringActiveParams extends Equatable {
  final String id;
  final bool active;

  const SetRecurringActiveParams({required this.id, required this.active});

  @override
  List<Object?> get props => [id, active];
}

/// Pauses or resumes a recurring item.
class SetRecurringActiveUseCase
    implements UseCase<void, SetRecurringActiveParams> {
  final RecurringRepository _repository;

  const SetRecurringActiveUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(SetRecurringActiveParams params) async {
    if (params.id.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_recurring'));
    }
    return _repository.setActive(params.id, active: params.active);
  }
}