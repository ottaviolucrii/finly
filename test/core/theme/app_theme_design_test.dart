import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('light', () {
    final theme = AppTheme.light;

    test('the page is light gray and the cards are white', () {
      expect(theme.scaffoldBackgroundColor, AppColors.canvas);
      expect(theme.cardTheme.color, AppColors.white);
      expect(theme.colorScheme.surface, AppColors.white);
    });

    test('the app bar blends with the page', () {
      expect(theme.appBarTheme.backgroundColor, AppColors.canvas);
      expect(theme.appBarTheme.titleTextStyle?.fontFamily, 'Poppins');
    });

    test('cards have round corners of 20', () {
      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(20));
    });

    test('lines, outlines and captions use the design tokens', () {
      expect(theme.colorScheme.outlineVariant, AppColors.hairline);
      expect(theme.colorScheme.outline, AppColors.border);
      expect(theme.colorScheme.onSurfaceVariant, AppColors.textMuted);
    });

    test('buttons are pills', () {
      final filled = theme.filledButtonTheme.style!.shape!.resolve(<WidgetState>{});
      final outlined = theme.outlinedButtonTheme.style!.shape!.resolve(<WidgetState>{});
      expect(filled, isA<StadiumBorder>());
      expect(outlined, isA<StadiumBorder>());
    });

    test('sheets have round tops', () {
      final shape = theme.bottomSheetTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, const BorderRadius.vertical(top: Radius.circular(28)));
    });
  });

  group('dark', () {
    final theme = AppTheme.dark;

    test('the page is near black and the cards are deep blue', () {
      expect(theme.scaffoldBackgroundColor, AppColors.canvasDark);
      expect(theme.cardTheme.color, AppColors.cardDark);
    });

    test('text and captions are light', () {
      expect(theme.colorScheme.onSurface, AppColors.textOnDark);
      expect(theme.colorScheme.onSurfaceVariant, AppColors.textMutedDark);
    });
  });

  group('contrast of the new text colors', () {
    double luminance(Color c) => c.computeLuminance();
    double ratio(Color a, Color b) {
      final l1 = luminance(a), l2 = luminance(b);
      final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
      return (hi + 0.05) / (lo + 0.05);
    }

    test('captions on white pass 4.5:1', () {
      expect(ratio(AppColors.textMuted, AppColors.white), greaterThanOrEqualTo(4.5));
    });

    test('captions on the page pass 4.5:1', () {
      expect(ratio(AppColors.textMuted, AppColors.canvas), greaterThanOrEqualTo(4.5));
    });

    test('gold text on light backgrounds passes 4.5:1', () {
      expect(ratio(AppColors.goldOnLight, AppColors.goldTint), greaterThanOrEqualTo(4.5));
    });

    test('money in, in green, passes 4.5:1 on white', () {
      expect(ratio(AppColors.positive, AppColors.white), greaterThanOrEqualTo(4.5));
    });

    test('secondary text on the deep blue band passes 4.5:1', () {
      expect(ratio(AppColors.onBand, AppColors.deepBlue), greaterThanOrEqualTo(4.5));
    });

    test('dark captions on dark cards pass 4.5:1', () {
      expect(ratio(AppColors.textMutedDark, AppColors.cardDark), greaterThanOrEqualTo(4.5));
    });
  });
}
