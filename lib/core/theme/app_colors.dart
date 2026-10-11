import 'package:flutter/material.dart';

/// Brand palette from the Finly visual identity guide, plus the tokens of the
/// 2026 design (surfaces, lines, tints) and a few accessibility tokens
/// (see docs/UI_GUIDE.md).
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

  // ---- 2026 design: light ----

  /// The page behind the cards.
  static const canvas = Color(0xFFF4F6F9);

  /// Lines between rows inside a card.
  static const hairline = Color(0xFFEEF1F5);

  /// Outlines of buttons, chips and fields.
  static const border = Color(0xFFD5DBE3);

  /// Tracks of progress bars and the background of segmented controls.
  static const track = Color(0xFFE6EAF0);

  /// Captions and secondary text (4.6:1 on white).
  static const textMuted = Color(0xFF5B6676);

  /// Background of icon badges and blue info chips.
  static const blueTint = Color(0xFFEEF3FD);

  /// Background of gold badges ("Pendente", "Parcialmente paga").
  static const goldTint = Color(0xFFFFF3E3);

  /// Gold text on a light background (the brand gold fails contrast there).
  static const goldOnLight = Color(0xFF8A4B00);

  /// Money that comes in.
  static const positive = Color(0xFF0B6B3A);
  static const positiveTint = Color(0xFFE7F5EC);

  /// Secondary text on the deep blue band.
  static const onBand = Color(0xFFC9D3DF);

  /// Gold text on the deep blue band.
  static const goldOnBand = Color(0xFFF6B467);

  // ---- 2026 design: dark ----

  static const canvasDark = Color(0xFF0C131A);
  static const cardDark = Color(0xFF16222F);
  static const hairlineDark = Color(0xFF22303F);
  static const borderDark = Color(0xFF2A3A4D);
  static const textMutedDark = Color(0xFFA9B4C2);
  static const blueTintDark = Color(0xFF1C3150);
}
