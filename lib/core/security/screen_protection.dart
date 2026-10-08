import 'package:flutter/services.dart';

/// Blocks screenshots and hides the screens of the app in the list of recent
/// apps (the `FLAG_SECURE` of Android). The choice is kept on the phone, by the
/// Android side, and applied before the first frame is drawn.
abstract class ScreenProtection {
  /// Whether the protection is on. Null when this phone or platform cannot do
  /// it (only Android can).
  Future<bool?> isEnabled();

  Future<void> setEnabled(bool enabled);
}

/// The name of the channel with the Android side (`MainActivity.kt`).
const String screenProtectionChannelName = 'finly/screen_protection';

class PlatformScreenProtection implements ScreenProtection {
  final MethodChannel _channel;

  PlatformScreenProtection([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(screenProtectionChannelName);

  @override
  Future<bool?> isEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } on MissingPluginException {
      // No Android side here (iOS, a computer, a test): nothing to protect.
      return null;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) {
    return _channel.invokeMethod<void>('setEnabled', {'enabled': enabled});
  }
}
