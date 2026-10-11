import 'package:finly/features/transactions/domain/entities/transaction_filter.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

/// The chips under the band of Extrato.
enum QuickFilter { all, income, expense, pending }

/// The first and the last day of the month of [date].
(DateTime, DateTime) monthRange(DateTime date) {
  final first = DateTime(date.year, date.month);
  final last = DateTime(date.year, date.month + 1, 0);
  return (first, last);
}

/// [filter] narrowed to the month of [month]; everything else is kept.
TransactionFilter filterForMonth(TransactionFilter filter, DateTime month) {
  final (from, to) = monthRange(month);
  return TransactionFilter(
    search: filter.search,
    type: filter.type,
    status: filter.status,
    accountId: filter.accountId,
    categoryId: filter.categoryId,
    from: from,
    to: to,
  );
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The month the filter shows, when its period is exactly one whole month.
/// Null for no period or any other period.
DateTime? monthOfFilter(TransactionFilter filter) {
  final from = filter.from;
  final to = filter.to;
  if (from == null || to == null) return null;
  final (first, last) = monthRange(from);
  if (!_sameDay(from, first) || !_sameDay(to, last)) return null;
  return first;
}

/// The chip that matches [filter], or null when the type and the status
/// were set in another way (in the filter sheet).
QuickFilter? quickOf(TransactionFilter filter) {
  final type = filter.type;
  final status = filter.status;
  if (type == null && status == null) return QuickFilter.all;
  if (type == TransactionType.income && status == null) return QuickFilter.income;
  if (type == TransactionType.expense && status == null) return QuickFilter.expense;
  if (type == null && status == TransactionStatus.pending) return QuickFilter.pending;
  return null;
}

/// [filter] with the type and the status of [quick]; everything else is kept.
TransactionFilter filterWithQuick(TransactionFilter filter, QuickFilter quick) {
  return TransactionFilter(
    search: filter.search,
    type: switch (quick) {
      QuickFilter.income => TransactionType.income,
      QuickFilter.expense => TransactionType.expense,
      _ => null,
    },
    status: quick == QuickFilter.pending ? TransactionStatus.pending : null,
    accountId: filter.accountId,
    categoryId: filter.categoryId,
    from: filter.from,
    to: filter.to,
  );
}

/// How many filters were set in the sheet, for the badge on its button. The
/// month and the chip are shown on screen already, so they do not count.
int sheetFilterCount(TransactionFilter filter) {
  var count = filter.pickerCount;
  if (monthOfFilter(filter) != null) count -= 1;
  final quick = quickOf(filter);
  if (quick != null && quick != QuickFilter.all) count -= 1;
  return count < 0 ? 0 : count;
}
