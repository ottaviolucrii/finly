import 'package:equatable/equatable.dart';

/// What was spent on one category in one month and currency.
class CategorySpendEntry extends Equatable {
  /// Null for expenses with no category.
  final String? categoryId;
  final String currency;
  final int spentCents;

  const CategorySpendEntry({
    required this.categoryId,
    required this.currency,
    required this.spentCents,
  });

  @override
  List<Object?> get props => [categoryId, currency, spentCents];
}