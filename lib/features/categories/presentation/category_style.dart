import 'package:finly/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Icon names used by the default categories (sql/03_logic.sql).
const Map<String, IconData> _icons = {
  'restaurant': Icons.restaurant,
  'home': Icons.home,
  'directions_car': Icons.directions_car,
  'favorite': Icons.favorite,
  'school': Icons.school,
  'celebration': Icons.celebration,
  'shopping_bag': Icons.shopping_bag,
  'receipt_long': Icons.receipt_long,
  'subscriptions': Icons.subscriptions,
  'category': Icons.category,
  'payments': Icons.payments,
  'trending_up': Icons.trending_up,
  'local_shipping': Icons.local_shipping,
  'groups': Icons.groups,
  'account_balance': Icons.account_balance,
  'apartment': Icons.apartment,
  'campaign': Icons.campaign,
  'cloud': Icons.cloud,
  'sell': Icons.sell,
  'handyman': Icons.handyman,
};

IconData categoryIcon(String name) => _icons[name] ?? Icons.category;

/// Reads "#F29D38" (or "F29D38"). Falls back to the brand gray.
Color categoryColor(String hex) {
  final clean = hex.startsWith('#') ? hex.substring(1) : hex;
  final value = clean.length == 6 ? int.tryParse(clean, radix: 16) : null;
  if (value == null) return AppColors.structure;
  return Color(0xFF000000 | value);
}