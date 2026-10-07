import 'package:equatable/equatable.dart';
import 'package:finly/features/appearance/domain/entities/appearance_mode.dart';

/// What went wrong, for the settings screen to say.
enum AppearanceError { none, saveFailed }

class AppearanceState extends Equatable {
  final AppearanceMode mode;

  /// The saved choice was read (until then the app follows the phone).
  final bool loaded;
  final AppearanceError error;

  const AppearanceState({
    this.mode = AppearanceMode.system,
    this.loaded = false,
    this.error = AppearanceError.none,
  });

  AppearanceState copyWith({
    AppearanceMode? mode,
    bool? loaded,
    AppearanceError? error,
  }) {
    return AppearanceState(
      mode: mode ?? this.mode,
      loaded: loaded ?? this.loaded,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [mode, loaded, error];
}
