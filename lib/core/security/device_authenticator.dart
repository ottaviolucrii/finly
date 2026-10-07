import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Asks the phone to check who is holding it: fingerprint, face, or the screen
/// lock (PIN, pattern). It is an interface so tests never touch the platform.
abstract class DeviceAuthenticator {
  /// True when the phone has a biometric sensor or a screen lock to ask.
  Future<bool> isSupported();

  /// Shows the system prompt. False when it was cancelled or failed; it never
  /// throws.
  Future<bool> authenticate({required String reason});
}

class LocalAuthDeviceAuthenticator implements DeviceAuthenticator {
  final LocalAuthentication _auth = LocalAuthentication();

  LocalAuthDeviceAuthenticator();

  @override
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('Device authentication check failed: $e');
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      // The system prompt accepts biometrics and also the PIN or pattern.
      return await _auth.authenticate(localizedReason: reason);
    } catch (e) {
      debugPrint('Device authentication failed: $e');
      return false;
    }
  }
}