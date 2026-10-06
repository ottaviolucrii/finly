import 'package:finly/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final entry in {'light': AppTheme.light, 'dark': AppTheme.dark}.entries) {
    group('${entry.key} theme', () {
      final text = entry.value.textTheme;

      test('titles use Poppins', () {
        expect(text.headlineLarge?.fontFamily, 'Poppins');
        expect(text.headlineSmall?.fontFamily, 'Poppins');
        expect(text.titleLarge?.fontFamily, 'Poppins');
      });

      test('body text and numbers use Inter', () {
        expect(text.bodyMedium?.fontFamily, 'Inter');
        expect(text.titleMedium?.fontFamily, 'Inter');
        expect(text.labelLarge?.fontFamily, 'Inter');
      });

      test('every style uses tabular figures so amounts line up', () {
        const tabular = FontFeature.tabularFigures();
        for (final style in [
          text.headlineSmall,
          text.titleLarge,
          text.titleMedium,
          text.bodyMedium,
          text.bodySmall,
          text.labelLarge,
        ]) {
          expect(style?.fontFeatures, contains(tabular));
        }
      });
    });
  }
}