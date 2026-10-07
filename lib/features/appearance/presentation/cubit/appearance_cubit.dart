import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/appearance/domain/entities/appearance_mode.dart';
import 'package:finly/features/appearance/domain/usecases/get_appearance_use_case.dart';
import 'package:finly/features/appearance/domain/usecases/save_appearance_use_case.dart';
import 'package:finly/features/appearance/presentation/cubit/appearance_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The light, dark or system theme. One instance for the whole app, above
/// `MaterialApp`: the gate loads the saved choice when someone signs in and
/// resets it when they sign out.
class AppearanceCubit extends Cubit<AppearanceState> {
  final GetAppearanceUseCase _getAppearance;
  final SaveAppearanceUseCase _saveAppearance;

  AppearanceCubit({
    required GetAppearanceUseCase getAppearance,
    required SaveAppearanceUseCase saveAppearance,
  })  : _getAppearance = getAppearance,
        _saveAppearance = saveAppearance,
        super(const AppearanceState());

  /// Reads the saved choice. If it cannot be read, the app keeps following the
  /// phone.
  Future<void> load() async {
    final result = await _getAppearance(const NoParams());
    if (isClosed) return;

    result.fold(
      (_) {},
      (mode) => emit(state.copyWith(mode: mode, loaded: true)),
    );
  }

  /// Changes the theme at once and saves the choice; if saving fails, the
  /// theme goes back and the screen can say so.
  Future<void> setMode(AppearanceMode mode) async {
    if (mode == state.mode) return;

    final previous = state.mode;
    emit(state.copyWith(mode: mode, error: AppearanceError.none));

    final result = await _saveAppearance(mode);
    if (isClosed) return;

    result.fold(
      (_) => emit(state.copyWith(mode: previous, error: AppearanceError.saveFailed)),
      (_) {},
    );
  }

  /// Nobody is signed in: back to following the phone.
  void reset() => emit(const AppearanceState());
}
