import 'package:finly/core/offline/remembered_user.dart';

/// Brings the login back when the library lost it because it could not renew an
/// expired login without internet. It gives the saved session to the library
/// again; once the internet is there, the library renews it.
class SessionRestorer {
  final SessionMemory memory;

  /// Whether the library has a session now.
  final bool Function() hasSession;

  /// Gives the saved session text to the library (it renews it if it expired).
  final Future<void> Function(String raw) recover;

  /// The least time between two tries, so a phone without internet is not asked
  /// again for every read.
  final Duration minGap;

  final DateTime Function() _clock;

  DateTime? _lastTry;
  bool _running = false;

  SessionRestorer({
    required this.memory,
    required this.hasSession,
    required this.recover,
    this.minGap = const Duration(seconds: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// True when the library has a session after the try.
  Future<bool> restore() async {
    if (hasSession()) return true;
    if (_running) return false;

    final now = _clock();
    final last = _lastTry;
    if (last != null && now.difference(last) < minGap) return false;

    _lastTry = now;
    _running = true;
    try {
      final raw = await memory.raw();
      if (raw == null) return false;

      await recover(raw);
      return hasSession();
    } catch (_) {
      // Still no internet, or the login is not valid any more: no session.
      return false;
    } finally {
      _running = false;
    }
  }
}
