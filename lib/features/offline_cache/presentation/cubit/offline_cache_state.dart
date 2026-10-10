import 'package:equatable/equatable.dart';

class OfflineCacheState extends Equatable {
  /// False until the phone has been read.
  final bool loaded;

  /// Whether copies of the data are kept for use without internet.
  final bool enabled;

  /// What the copies use, in bytes.
  final int sizeBytes;

  /// True while a change or the erasing is going on.
  final bool busy;

  /// How many times the copies were erased: the screen says so each time.
  final int erased;

  /// True when the last change was refused.
  final bool failed;

  const OfflineCacheState({
    this.loaded = false,
    this.enabled = true,
    this.sizeBytes = 0,
    this.busy = false,
    this.erased = 0,
    this.failed = false,
  });

  OfflineCacheState copyWith({
    bool? loaded,
    bool? enabled,
    int? sizeBytes,
    bool? busy,
    int? erased,
    bool? failed,
  }) {
    return OfflineCacheState(
      loaded: loaded ?? this.loaded,
      enabled: enabled ?? this.enabled,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      busy: busy ?? this.busy,
      erased: erased ?? this.erased,
      failed: failed ?? this.failed,
    );
  }

  @override
  List<Object?> get props => [loaded, enabled, sizeBytes, busy, erased, failed];
}
