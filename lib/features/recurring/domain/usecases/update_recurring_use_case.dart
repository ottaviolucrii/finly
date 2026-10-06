import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/recurring/domain/repositories/recurring_repository.dart';

class UpdateRecurringParams extends Equatable {
  final String id;

  /// Null means "no category".
  final String? categoryId;
  final int amountCents;
  final String description;

  /// The item's start date, only used to check the end date.
  final DateTime startDate;
  final DateTime? endDate;

  const UpdateRecurringParams({
    required this.id,
    this.categoryId,
    required this.amountCents,
    required this.description,
    required this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props =>
      [id, categoryId, amountCents, description, startDate, endDate];
}

/// Changes what a recurring item generates from now on. The schedule never
/// changes.
class UpdateRecurringUseCase
    implements UseCase<void, UpdateRecurringParams> {
  final RecurringRepository _repository;

  const UpdateRecurringUseCase(this._repository);

  @override
  Future<Either<Failure, void>> call(UpdateRecurringParams params) async {
    if (params.id.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_recurring'));
    }
    if (params.amountCents <= 0) {
      return const Left(ValidationFailure('invalid_amount'));
    }
    final description = params.description.trim();
    if (description.isEmpty || description.length > 200) {
      return const Left(ValidationFailure('invalid_description'));
    }
    final end = params.endDate;
    if (end != null && end.isBefore(params.startDate)) {
      return const Left(ValidationFailure('invalid_end_date'));
    }

    return _repository.updateRecurring(
      id: params.id,
      categoryId: params.categoryId,
      amountCents: params.amountCents,
      description: description,
      endDate: end,
    );
  }
}