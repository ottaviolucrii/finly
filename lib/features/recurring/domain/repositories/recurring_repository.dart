import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:finly/features/recurring/domain/entities/recurring_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

abstract class RecurringRepository {
  /// Every recurring item of the workspace, paused ones included.
  Future<Either<Failure, List<RecurringEntity>>> getRecurring(
    String workspaceId,
  );

  Future<Either<Failure, RecurringEntity>> createRecurring({
    required String workspaceId,
    required String accountId,
    String? categoryId,
    required TransactionType type,
    required int amountCents,
    required String currency,
    required String description,
    required RecurrenceFrequency frequency,
    required int intervalCount,
    required DateTime startDate,
    DateTime? endDate,
  });

  /// Changes the description, amount, category and end date. The schedule
  /// never changes. Pending occurrences from today on follow the new values;
  /// pending ones after a new end date are removed.
  Future<Either<Failure, void>> updateRecurring({
    required String id,
    String? categoryId,
    required int amountCents,
    required String description,
    DateTime? endDate,
  });

  /// Deletes the item and its pending occurrences. What was already
  /// confirmed stays in the history.
  Future<Either<Failure, void>> deleteRecurring(String id);

  /// Pauses or resumes an item. Nothing is deleted.
  Future<Either<Failure, void>> setActive(String id, {required bool active});

  /// Creates, as pending transactions, the occurrences that are due (up to
  /// 35 days ahead). Returns how many were created.
  Future<Either<Failure, int>> generateDue();
}