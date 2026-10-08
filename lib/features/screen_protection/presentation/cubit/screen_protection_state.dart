import 'package:equatable/equatable.dart';

enum ScreenProtectionStatus {
  /// Reading what the phone has.
  loading,

  /// The switch can be used.
  ready,

  /// This phone or platform cannot block screenshots: the section is hidden.
  unsupported,
}

class ScreenProtectionState extends Equatable {
  final ScreenProtectionStatus status;
  final bool enabled;

  /// True while a change is being saved.
  final bool saving;

  /// True when the last change was refused (the switch went back).
  final bool failed;

  const ScreenProtectionState({
    this.status = ScreenProtectionStatus.loading,
    this.enabled = false,
    this.saving = false,
    this.failed = false,
  });

  @override
  List<Object?> get props => [status, enabled, saving, failed];
}
