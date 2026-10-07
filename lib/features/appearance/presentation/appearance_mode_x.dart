import 'package:finly/features/appearance/domain/entities/appearance_mode.dart';
import 'package:flutter/material.dart';

/// What Flutter and the screens need to know about an [AppearanceMode].
extension AppearanceModeX on AppearanceMode {
  /// The mode `MaterialApp` understands.
  ThemeMode get themeMode {
    switch (this) {
      case AppearanceMode.system:
        return ThemeMode.system;
      case AppearanceMode.light:
        return ThemeMode.light;
      case AppearanceMode.dark:
        return ThemeMode.dark;
    }
  }

  /// The name shown to the user (Portuguese for now; replaced by proper
  /// localisation in a later phase).
  String get label {
    switch (this) {
      case AppearanceMode.system:
        return 'Sistema';
      case AppearanceMode.light:
        return 'Claro';
      case AppearanceMode.dark:
        return 'Escuro';
    }
  }
}
