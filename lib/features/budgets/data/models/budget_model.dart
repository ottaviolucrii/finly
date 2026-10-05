import 'package:finly/features/budgets/domain/entities/budget_entity.dart';

class BudgetModel extends BudgetEntity {
  const BudgetModel({
    required super.id,
    required super.workspaceId,
    required super.categoryId,
    required super.effectiveFrom,
    required super.limitCents,
    required super.currency,
  });

  /// [map] is a row of the `budgets` table.
  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] as String,
      workspaceId: map['workspace_id'] as String,
      categoryId: map['category_id'] as String,
      effectiveFrom: DateTime.parse(map['effective_from'] as String),
      limitCents: (map['limit_cents'] as num).toInt(),
      currency: map['currency'] as String,
    );
  }
}