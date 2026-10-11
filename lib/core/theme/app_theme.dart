import 'package:finly/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// The look of the whole app: the brand colors, Poppins for titles and Inter
/// for everything else, and the surfaces of the 2026 design (a light gray page
/// with white cards; in dark mode a near-black page with deep blue cards).
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
          onSurfaceVariant: AppColors.textMuted,
          outline: AppColors.border,
          outlineVariant: AppColors.hairline,
        ),
        canvas: AppColors.canvas,
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
          surface: AppColors.cardDark,
          onSurface: AppColors.textOnDark,
          onSurfaceVariant: AppColors.textMutedDark,
          outline: AppColors.borderDark,
          outlineVariant: AppColors.hairlineDark,
        ),
        canvas: AppColors.canvasDark,
      );

  static ThemeData _build(ColorScheme scheme, {required Color canvas}) {
    const buttonText = TextStyle(
      fontFamily: _bodyFont,
      fontWeight: FontWeight.w600,
      fontSize: 15,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _bodyFont,
      scaffoldBackgroundColor: canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // No titleTextStyle here: the title then uses titleLarge (Poppins) in
        // the bar's own foreground color, so a page with a blue bar and a
        // white foreground gets a white title, not a dark one.
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: AppColors.midnight.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outline),
          foregroundColor: scheme.onSurface,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: buttonText),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outline),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    // Titles use Poppins, everything else (body, numbers) uses Inter.
    TextStyle? title(TextStyle? style) =>
        style?.copyWith(fontFamily: _titleFont, fontWeight: FontWeight.w600);
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
