import 'package:finly/features/dashboard/domain/entities/category_spend_entry.dart';

class CategorySpendEntryModel extends CategorySpendEntry {
  const CategorySpendEntryModel({
    required super.categoryId,
    required super.currency,
    required super.spentCents,
  });

  /// [map] is a row of the `monthly_category_spend` view.
  factory CategorySpendEntryModel.fromMap(Map<String, dynamic> map) {
    return CategorySpendEntryModel(
      categoryId: map['category_id'] as String?,
      currency: map['currency'] as String,
      spentCents: (map['spent_cents'] as num).toInt(),
    );
  }
}