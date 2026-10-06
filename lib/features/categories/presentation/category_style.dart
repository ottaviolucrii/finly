import 'package:finly/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Icon names used by the default categories (sql/03_logic.sql), and offered
/// when creating or editing one.
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

/// The icons a category can use, in the order they are offered.
List<String> get categoryIconNames => _icons.keys.toList();

/// The colours offered for a category (hex, as stored).
const List<String> categoryColorChoices = [
  '#1060E3',
  '#5B8DEF',
  '#1A2E44',
  '#F29D38',
  '#E36414',
  '#B42318',
  '#C2569B',
  '#6B5BD2',
  '#0E8F8F',
  '#1E7A4F',
  '#8A5A2B',
  '#A8A8A8',
];

IconData categoryIcon(String name) => _icons[name] ?? Icons.category;

/// Reads "#F29D38" (or "F29D38"). Falls back to the brand gray.
Color categoryColor(String hex) {
  final clean = hex.startsWith('#') ? hex.substring(1) : hex;
  final value = clean.length == 6 ? int.tryParse(clean, radix: 16) : null;
  if (value == null) return AppColors.structure;
  return Color(0xFF000000 | value);
}