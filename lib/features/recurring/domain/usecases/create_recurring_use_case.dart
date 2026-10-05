import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:finly/features/recurring/domain/entities/recurring_entity.dart';
import 'package:finly/features/recurring/domain/repositories/recurring_repository.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

class CreateRecurringParams extends Equatable {
  final String workspaceId;
  final String accountId;
  final String? categoryId;
  final TransactionType type;
  final int amountCents;
  final String currency;
  final String description;
  final RecurrenceFrequency frequency;
  final int intervalCount;
  final DateTime startDate;
  final DateTime? endDate;

  const CreateRecurringParams({
    required this.workspaceId,
    required this.accountId,
    this.categoryId,
    required this.type,
    required this.amountCents,
    required this.currency,
    required this.description,
    required this.frequency,
    required this.intervalCount,
    required this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [
        workspaceId,
        accountId,
        categoryId,
        type,
        amountCents,
        currency,
        description,
        frequency,
        intervalCount,
        startDate,
        endDate,
      ];
}

class CreateRecurringUseCase
    implements UseCase<RecurringEntity, CreateRecurringParams> {
  final RecurringRepository _repository;

  const CreateRecurringUseCase(this._repository);

  @override
  Future<Either<Failure, RecurringEntity>> call(
    CreateRecurringParams params,
  ) async {
    if (params.accountId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_account'));
    }
    // Transfers have their own flow.
    if (params.type.isTransfer) {
      return const Left(ValidationFailure('invalid_transaction_type'));
    }
    if (params.amountCents <= 0) {
      return const Left(ValidationFailure('invalid_amount'));
    }
    final description = params.description.trim();
    if (description.isEmpty || description.length > 200) {
      return const Left(ValidationFailure('invalid_description'));
    }
    if (params.intervalCount < 1 || params.intervalCount > 52) {
      return const Left(ValidationFailure('invalid_interval'));
    }
    final end = params.endDate;
    if (end != null && end.isBefore(params.startDate)) {
      return const Left(ValidationFailure('invalid_end_date'));
    }

    return _repository.createRecurring(
      workspaceId: params.workspaceId,
      accountId: params.accountId,
      categoryId: params.categoryId,
      type: params.type,
      amountCents: params.amountCents,
      currency: params.currency,
      description: description,
      frequency: params.frequency,
      intervalCount: params.intervalCount,
      startDate: params.startDate,
      endDate: end,
    );
  }
}