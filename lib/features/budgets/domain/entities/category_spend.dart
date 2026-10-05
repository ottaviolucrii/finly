import 'package:equatable/equatable.dart';

/// What was spent on one category, in one currency, in one month.
class CategorySpend extends Equatable {
  /// Null for expenses that have no category.
  final String? categoryId;
  final String currency;
  final int spentCents;

  const CategorySpend({
    required this.categoryId,
    required this.currency,
    required this.spentCents,
  });

  @override
  List<Object?> get props => [categoryId, currency, spentCents];
}