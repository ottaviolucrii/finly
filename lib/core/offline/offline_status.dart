import 'package:flutter/foundation.dart';

/// What the app knows about the connection, for the banner and for the screens:
/// whether it is showing copies instead of live data, how old they are, and
/// whether the internet came back.
class OfflineStatus extends ChangeNotifier {
  bool _offline = false;
  bool _backOnline = false;
  DateTime? _cachedSince;
  int _refreshEpoch = 0;

  /// True while the app shows saved copies because the server cannot be reached.
  bool get isOffline => _offline;

  /// True when the server answered again after a time offline: the screens may
  /// still show old copies, so the person is offered to refresh.
  bool get isBackOnline => _backOnline;

  /// The oldest copy shown during this time offline, if any.
  DateTime? get cachedSince => _cachedSince;

  /// Goes up each time the person asks to refresh. The app builds its screens
  /// again when it changes.
  int get refreshEpoch => _refreshEpoch;

  /// A request could not reach the server.
  void markOffline() {
    if (_offline) return;
    _offline = true;
    _backOnline = false;
    notifyListeners();
  }

  /// A copy made at [savedAt] was shown in place of the live answer.
  void markServedFromCache(DateTime savedAt) {
    final wasOffline = _offline;
    final since = _cachedSince;
    final older = since == null || savedAt.isBefore(since);

    _offline = true;
    _backOnline = false;
    if (older) _cachedSince = savedAt;

    if (!wasOffline || older) notifyListeners();
  }

  /// The server answered.
  void markOnline() {
    if (!_offline) return;
    _offline = false;
    _backOnline = true;
    _cachedSince = null;
    notifyListeners();
  }

  /// The person asked to refresh: the screens are built again with live data.
  void refresh() {
    _backOnline = false;
    _refreshEpoch++;
    notifyListeners();
  }
}
