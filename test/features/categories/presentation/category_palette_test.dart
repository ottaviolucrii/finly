import 'package:finly/features/categories/domain/usecases/create_category_use_case.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every colour offered is one the database accepts', () {
    for (final hex in categoryColorChoices) {
      expect(categoryColorPattern.hasMatch(hex), isTrue, reason: hex);
    }
  });

  test('the colours offered are all different', () {
    expect(categoryColorChoices.toSet().length, categoryColorChoices.length);
  });

  test('every icon offered is a real icon, not the fallback', () {
    for (final name in categoryIconNames) {
      if (name == 'category') continue;
      expect(categoryIcon(name), isNot(Icons.category), reason: name);
    }
  });

  test('the icons offered are all different', () {
    expect(categoryIconNames.toSet().length, categoryIconNames.length);
  });
}