import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('categoryIcon', () {
    test('maps the icon names of the default categories', () {
      expect(categoryIcon('restaurant'), Icons.restaurant);
      expect(categoryIcon('payments'), Icons.payments);
      expect(categoryIcon('local_shipping'), Icons.local_shipping);
    });

    test('falls back to the generic icon for unknown names', () {
      expect(categoryIcon('does_not_exist'), Icons.category);
    });
  });

  group('categoryColor', () {
    test('reads a hex colour with or without the hash', () {
      expect(categoryColor('#1060E3'), const Color(0xFF1060E3));
      expect(categoryColor('F29D38'), const Color(0xFFF29D38));
    });

    test('falls back to the brand gray for invalid values', () {
      expect(categoryColor('blue'), AppColors.structure);
      expect(categoryColor('#12345'), AppColors.structure);
      expect(categoryColor('#GGGGGG'), AppColors.structure);
    });
  });
}