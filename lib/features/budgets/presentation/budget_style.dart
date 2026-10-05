import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:flutter/material.dart';

/// Text that goes with the colour, so colour is never the only signal.
String? budgetLevelLabel(BudgetLevel level) => switch (level) {
      BudgetLevel.normal => null,
      BudgetLevel.warning => 'Perto do limite',
      BudgetLevel.over => 'Acima do orçamento',
    };

Color budgetLevelColor(BuildContext context, BudgetLevel level) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  return switch (level) {
    BudgetLevel.normal => theme.colorScheme.primary,
    // The brand gold reads well on dark; the darker orange reads well on light.
    BudgetLevel.warning => dark ? AppColors.gold : AppColors.warning,
    BudgetLevel.over => theme.colorScheme.error,
  };
}