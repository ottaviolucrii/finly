import 'package:flutter/material.dart';

/// Brand palette from the Finly visual identity guide, plus a few
/// accessibility tokens (see docs/UI_GUIDE.md).
abstract final class AppColors {
  // Brand
  static const midnight = Color(0xFF101820);
  static const white = Color(0xFFFFFFFF);
  static const techBlue = Color(0xFF1060E3);
  static const gold = Color(0xFFF29D38);
  static const deepBlue = Color(0xFF1A2E44);
  static const structure = Color(0xFFA8A8A8);

  // Added for accessibility and states
  static const textSecondary = Color(0xFF4B5563);
  static const surfaceTint = Color(0xFFF3F6FC);
  static const success = Color(0xFF1E7A4F);
  static const danger = Color(0xFFB42318);
  static const warning = Color(0xFFB54708);

  // Dark mode
  static const techBlueOnDark = Color(0xFF5B8DEF);
  static const dangerOnDark = Color(0xFFF97066);
  static const textOnDark = Color(0xFFE6E9EE);
}