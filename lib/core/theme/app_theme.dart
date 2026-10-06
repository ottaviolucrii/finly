import 'package:finly/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _titleFont = 'Poppins';
  static const _bodyFont = 'Inter';

  /// Every digit has the same width, so amounts line up in columns.
  static const _tabularFigures = [FontFeature.tabularFigures()];

  static ThemeData get light => _build(
        const ColorScheme(
          brightness: Brightness.light,
          primary: AppColors.techBlue,
          onPrimary: AppColors.white,
          secondary: AppColors.gold,
          onSecondary: AppColors.midnight,
          error: AppColors.danger,
          onError: AppColors.white,
          surface: AppColors.white,
          onSurface: AppColors.midnight,
          outline: AppColors.structure,
        ),
      );

  static ThemeData get dark => _build(
        const ColorScheme(
          brightness: Brightness.dark,
          primary: AppColors.techBlueOnDark,
          onPrimary: AppColors.midnight,
          secondary: AppColors.gold,
          onSecondary: AppColors.midnight,
          error: AppColors.dangerOnDark,
          onError: AppColors.midnight,
          surface: AppColors.midnight,
          onSurface: AppColors.textOnDark,
          outline: AppColors.structure,
        ),
      );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _bodyFont,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );

    // Titles use Poppins, everything else (body, numbers) uses Inter.
    TextStyle? title(TextStyle? style) => style?.copyWith(fontFamily: _titleFont);
    final t = base.textTheme;
    final titled = t.copyWith(
      headlineLarge: title(t.headlineLarge),
      headlineMedium: title(t.headlineMedium),
      headlineSmall: title(t.headlineSmall),
      titleLarge: title(t.titleLarge),
    );

    return base.copyWith(textTheme: _withTabularFigures(titled));
  }

  static TextTheme _withTabularFigures(TextTheme t) {
    TextStyle? tab(TextStyle? style) =>
        style?.copyWith(fontFeatures: _tabularFigures);

    return t.copyWith(
      displayLarge: tab(t.displayLarge),
      displayMedium: tab(t.displayMedium),
      displaySmall: tab(t.displaySmall),
      headlineLarge: tab(t.headlineLarge),
      headlineMedium: tab(t.headlineMedium),
      headlineSmall: tab(t.headlineSmall),
      titleLarge: tab(t.titleLarge),
      titleMedium: tab(t.titleMedium),
      titleSmall: tab(t.titleSmall),
      bodyLarge: tab(t.bodyLarge),
      bodyMedium: tab(t.bodyMedium),
      bodySmall: tab(t.bodySmall),
      labelLarge: tab(t.labelLarge),
      labelMedium: tab(t.labelMedium),
      labelSmall: tab(t.labelSmall),
    );
  }
}