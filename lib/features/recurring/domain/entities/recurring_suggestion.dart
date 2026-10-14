import 'package:equatable/equatable.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

/// Something that comes back every month in the person's history, which could
/// become a recurring item (see sql/23_recurring_suggestions.sql).
class RecurringSuggestion extends Equatable {
  final String description;
  final TransactionType type;
  final int amountCents;
  final String accountId;
  final String? categoryId;

  /// The day of the month it usually falls on.
  final int dayOfMonth;

  /// In how many of the last months it was seen.
  final int monthsSeen;

  /// The last time it appeared (it may be an upcoming entry).
  final DateTime? lastSeen;

  const RecurringSuggestion({
    required this.description,
    required this.type,
    required this.amountCents,
    required this.accountId,
    required this.dayOfMonth,
    required this.monthsSeen,
    this.categoryId,
    this.lastSeen,
  });

  factory RecurringSuggestion.fromMap(Map<String, dynamic> map) => RecurringSuggestion(
        description: map['description'] as String,
        type: map['type'] == 'income' ? TransactionType.income : TransactionType.expense,
        amountCents: (map['amount_cents'] as num).toInt(),
        accountId: map['account_id'] as String,
        categoryId: map['category_id'] as String?,
        dayOfMonth: (map['day_of_month'] as num).toInt(),
        monthsSeen: (map['months_seen'] as num).toInt(),
        lastSeen: map['last_seen'] == null ? null : DateTime.tryParse('${map['last_seen']}'),
      );

  /// What the person closed with "Agora não" is remembered by this.
  String get key => description.trim().toLowerCase();

  @override
  List<Object?> get props => [description, type, amountCents, accountId, categoryId, dayOfMonth, monthsSeen, lastSeen];
}

/// The next date, today or later, that falls on [dayOfMonth] (the last day of
/// the month when it has fewer days). A recurring item starts there, so it
/// never makes a transaction in the past.
DateTime nextDayOfMonth(int dayOfMonth, DateTime today) {
  final base = DateTime(today.year, today.month, today.day);

  DateTime inMonth(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, dayOfMonth > lastDay ? lastDay : dayOfMonth);
  }

  final thisMonth = inMonth(base.year, base.month);
  return thisMonth.isBefore(base) ? inMonth(base.year, base.month + 1) : thisMonth;
}

/// Where a recurring item made from [suggestion] should start: the usual day,
/// in the first month after the last time it appeared (so it never repeats an
/// entry the person already has), and never in the past.
DateTime suggestedStart(RecurringSuggestion suggestion, DateTime today) {
  final next = nextDayOfMonth(suggestion.dayOfMonth, today);
  final seen = suggestion.lastSeen;
  if (seen == null) return next;
  final after = nextDayOfMonth(suggestion.dayOfMonth, DateTime(seen.year, seen.month + 1));
  return after.isAfter(next) ? after : next;
}
