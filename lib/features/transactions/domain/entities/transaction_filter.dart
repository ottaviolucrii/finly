import 'package:equatable/equatable.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

/// What the transactions list is narrowed down to. A filter with nothing set
/// shows everything.
class TransactionFilter extends Equatable {
  /// Text searched in the description (case does not matter).
  final String search;

  /// Income or expense.
  final TransactionType? type;

  /// Pending or posted.
  final TransactionStatus? status;
  final String? accountId;
  final String? categoryId;

  const TransactionFilter({
    this.search = '',
    this.type,
    this.status,
    this.accountId,
    this.categoryId,
  });

  /// How many pickers are set (the search box is not counted: it is always
  /// visible). Used for the badge on the filter button.
  int get pickerCount =>
      (type != null ? 1 : 0) +
      (status != null ? 1 : 0) +
      (accountId != null ? 1 : 0) +
      (categoryId != null ? 1 : 0);

  /// True when anything narrows the list, search included.
  bool get isActive => pickerCount > 0 || search.trim().isNotEmpty;

  /// The same filter with a new search text.
  TransactionFilter withSearch(String text) => TransactionFilter(
        search: text,
        type: type,
        status: status,
        accountId: accountId,
        categoryId: categoryId,
      );

  @override
  List<Object?> get props => [search, type, status, accountId, categoryId];
}