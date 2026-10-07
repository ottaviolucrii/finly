import 'package:finly/features/appearance/domain/entities/appearance_mode.dart';
import 'package:finly/features/appearance/presentation/appearance_mode_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppearanceMode', () {
    test('uses the values of the database enum', () {
      expect(AppearanceMode.system.dbValue, 'system');
      expect(AppearanceMode.light.dbValue, 'light');
      expect(AppearanceMode.dark.dbValue, 'dark');
    });

    test('reads every value back from the database', () {
      for (final mode in AppearanceMode.values) {
        expect(AppearanceMode.fromDb(mode.dbValue), mode);
      }
    });

    test('an unknown or missing value follows the phone', () {
      expect(AppearanceMode.fromDb(null), AppearanceMode.system);
      expect(AppearanceMode.fromDb(''), AppearanceMode.system);
      expect(AppearanceMode.fromDb('sepia'), AppearanceMode.system);
    });
  });

  group('AppearanceModeX', () {
    test('maps to the theme mode of Flutter', () {
      expect(AppearanceMode.system.themeMode, ThemeMode.system);
      expect(AppearanceMode.light.themeMode, ThemeMode.light);
      expect(AppearanceMode.dark.themeMode, ThemeMode.dark);
    });

    test('has a name for the screen', () {
      expect(AppearanceMode.system.label, 'Sistema');
      expect(AppearanceMode.light.label, 'Claro');
      expect(AppearanceMode.dark.label, 'Escuro');
    });
  });
}
