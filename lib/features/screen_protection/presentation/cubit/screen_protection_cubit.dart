import 'package:finly/core/security/screen_protection.dart';
import 'package:finly/features/screen_protection/presentation/cubit/screen_protection_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The switch that blocks screenshots.
class ScreenProtectionCubit extends Cubit<ScreenProtectionState> {
  final ScreenProtection _protection;

  ScreenProtectionCubit(this._protection) : super(const ScreenProtectionState());

  /// Reads what the phone has. If it cannot be read, the section stays hidden.
  Future<void> load() async {
    try {
      final enabled = await _protection.isEnabled();
      if (isClosed) return;

      emit(
        enabled == null
            ? const ScreenProtectionState(status: ScreenProtectionStatus.unsupported)
            : ScreenProtectionState(status: ScreenProtectionStatus.ready, enabled: enabled),
      );
    } catch (e) {
      debugPrint('Screen protection could not be read: $e');
      if (!isClosed) {
        emit(const ScreenProtectionState(status: ScreenProtectionStatus.unsupported));
      }
    }
  }

  /// Turns the protection on or off. The switch moves at once; if the phone
  /// refuses, it goes back and [ScreenProtectionState.failed] says so.
  Future<void> setEnabled(bool value) async {
    if (state.status != ScreenProtectionStatus.ready || state.saving) return;
    if (value == state.enabled) return;

    final before = state.enabled;
    emit(ScreenProtectionState(
      status: ScreenProtectionStatus.ready,
      enabled: value,
      saving: true,
    ));

    try {
      await _protection.setEnabled(value);
      if (isClosed) return;
      emit(ScreenProtectionState(status: ScreenProtectionStatus.ready, enabled: value));
    } catch (e) {
      debugPrint('Screen protection could not be changed: $e');
      if (isClosed) return;
      emit(ScreenProtectionState(
        status: ScreenProtectionStatus.ready,
        enabled: before,
        failed: true,
      ));
    }
  }
}
