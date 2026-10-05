import 'package:equatable/equatable.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:finly/features/recurring/domain/recurrence_rules.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

/// A bill or income that repeats (rent, a subscription, a salary).
class RecurringEntity extends Equatable {
  final String id;
  final String workspaceId;
  final String accountId;
  final String? categoryId;

  /// Income or expense (never a transfer).
  final TransactionType type;
  final int amountCents;
  final String currency;
  final String description;
  final RecurrenceFrequency frequency;

  /// Repeats every [intervalCount] days, weeks, months or years.
  final int intervalCount;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;

  const RecurringEntity({
    required this.id,
    required this.workspaceId,
    required this.accountId,
    required this.categoryId,
    required this.type,
    required this.amountCents,
    required this.currency,
    required this.description,
    required this.frequency,
    required this.intervalCount,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  Money get amount => Money(amountCents, currency);

  /// The next date on or after [today]; null when the series has ended.
  DateTime? nextDate(DateTime today) => nextOccurrence(
        start: startDate,
        frequency: frequency,
        intervalCount: intervalCount,
        endDate: endDate,
        today: today,
      );

  @override
  List<Object?> get props => [
        id,
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
        isActive,
      ];
}