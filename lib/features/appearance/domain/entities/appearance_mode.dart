/// How the app picks its colours: follow the phone, or always light, or always
/// dark. The names are the values of the `theme_mode` enum of `user_settings`.
enum AppearanceMode {
  system('system'),
  light('light'),
  dark('dark');

  final String dbValue;

  const AppearanceMode(this.dbValue);

  /// An unknown or missing value follows the phone, the safe default.
  static AppearanceMode fromDb(String? value) {
    for (final mode in AppearanceMode.values) {
      if (mode.dbValue == value) return mode;
    }
    return AppearanceMode.system;
  }
}
