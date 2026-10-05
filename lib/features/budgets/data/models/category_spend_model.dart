import 'package:finly/features/budgets/domain/entities/category_spend.dart';

class CategorySpendModel extends CategorySpend {
  const CategorySpendModel({
    required super.categoryId,
    required super.currency,
    required super.spentCents,
  });

  /// [map] is a row of the `monthly_category_spend` view.
  factory CategorySpendModel.fromMap(Map<String, dynamic> map) {
    return CategorySpendModel(
      categoryId: map['category_id'] as String?,
      currency: map['currency'] as String,
      spentCents: (map['spent_cents'] as num).toInt(),
    );
  }
}