import 'dart:async';

import 'package:finly/core/offline/offline_status.dart';

/// While the app is offline, asks now and then whether the server can be
/// reached again, so the banner can tell the person the internet came back
/// even when nothing on screen made a request.
class OfflineProbe {
  final OfflineStatus status;

  /// True when the server answered (any answer counts).
  final Future<bool> Function() reachable;
  final Duration interval;

  Timer? _timer;
  bool _checking = false;

  OfflineProbe({
    required this.status,
    required this.reachable,
    this.interval = const Duration(seconds: 10),
  }) {
    status.addListener(_onChange);
    _onChange();
  }

  void _onChange() {
    if (status.isOffline) {
      _timer ??= Timer.periodic(interval, (_) => checkNow());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Asks once. It does nothing when the app is not offline or an answer is
  /// already awaited.
  Future<void> checkNow() async {
    if (_checking || !status.isOffline) return;
    _checking = true;
    try {
      if (await reachable()) status.markOnline();
    } catch (_) {
      // No answer: still offline.
    } finally {
      _checking = false;
    }
  }

  void dispose() {
    status.removeListener(_onChange);
    _timer?.cancel();
    _timer = null;
  }
}
