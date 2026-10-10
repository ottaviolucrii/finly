import 'package:finly/core/offline/cache_store.dart';
import 'package:finly/features/offline_cache/presentation/cubit/offline_cache_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The settings of the copies kept for use without internet: turn them off, see
/// how much space they use, erase them.
class OfflineCacheCubit extends Cubit<OfflineCacheState> {
  final CacheStore _store;

  OfflineCacheCubit(this._store) : super(const OfflineCacheState());

  Future<void> load() async {
    try {
      final enabled = await _store.isEnabled();
      final size = await _store.sizeBytes();
      if (isClosed) return;
      emit(OfflineCacheState(loaded: true, enabled: enabled, sizeBytes: size));
    } catch (e) {
      debugPrint('The offline copies could not be read: $e');
      if (!isClosed) emit(state.copyWith(loaded: true, failed: true));
    }
  }

  /// Turns the copies on or off. Turning them off also erases what was kept:
  /// the person asked not to keep data on the phone.
  Future<void> setEnabled(bool value) async {
    if (state.busy || value == state.enabled) return;

    final before = state.enabled;
    emit(state.copyWith(enabled: value, busy: true, failed: false));

    try {
      await _store.setEnabled(value);
      if (!value) await _store.clear();
      final size = await _store.sizeBytes();
      if (isClosed) return;
      emit(state.copyWith(busy: false, sizeBytes: size, erased: value ? state.erased : state.erased + 1));
    } catch (e) {
      debugPrint('The offline copies could not be changed: $e');
      if (!isClosed) emit(state.copyWith(enabled: before, busy: false, failed: true));
    }
  }

  /// Erases every copy kept on the phone.
  Future<void> erase() async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, failed: false));

    try {
      await _store.clear();
      final size = await _store.sizeBytes();
      if (isClosed) return;
      emit(state.copyWith(busy: false, sizeBytes: size, erased: state.erased + 1));
    } catch (e) {
      debugPrint('The offline copies could not be erased: $e');
      if (!isClosed) emit(state.copyWith(busy: false, failed: true));
    }
  }
}
