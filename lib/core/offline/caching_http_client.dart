import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:finly/core/offline/cache_key.dart';
import 'package:finly/core/offline/cache_store.dart';
import 'package:finly/core/offline/cached_response.dart';
import 'package:finly/core/offline/offline_status.dart';
import 'package:http/http.dart' as http;

/// The headers of an answer worth keeping.
const List<String> _headersKept = ['content-type', 'content-range'];

/// An HTTP client that keeps a copy of every read of the database and answers
/// with the copy when the server cannot be reached.
///
/// It sits under the whole app, so no screen, use case or repository needs to
/// know about it. Only reads (GET of the REST API) are copied. Everything that
/// changes data goes straight to the server and fails, as it always did, when
/// there is no connection. Errors of the server are never copied.
class CachingHttpClient extends http.BaseClient {
  final http.Client _inner;
  final CacheStore _store;
  final OfflineStatus _status;
  final Duration _slowAfter;
  final DateTime Function() _clock;
  final Future<String?> Function()? _rememberedUserId;
  final Future<void> Function()? _restoreSession;

  /// [slowAfter]: when a copy exists and the server has not answered by then,
  /// the copy is shown (and updated when the answer finally arrives).
  ///
  /// [rememberedUserId] says who was signed in when the login library has no
  /// session (it could not renew an expired login without internet); the copies
  /// of that person then answer, and [restoreSession] is asked to bring the
  /// login back.
  CachingHttpClient({
    required http.Client inner,
    required CacheStore store,
    required OfflineStatus status,
    Duration slowAfter = const Duration(seconds: 6),
    DateTime Function()? clock,
    Future<String?> Function()? rememberedUserId,
    Future<void> Function()? restoreSession,
  })  : _inner = inner,
        _store = store,
        _status = status,
        _slowAfter = slowAfter,
        _clock = clock ?? DateTime.now,
        _rememberedUserId = rememberedUserId,
        _restoreSession = restoreSession;

  static bool _isRead(http.BaseRequest request) {
    return request.method == 'GET' && request.url.path.contains('/rest/v1/');
  }

  static bool _isNetworkError(Object error) {
    return error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException ||
        error is HandshakeException ||
        error is TlsException;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!_isRead(request) || !await _store.isEnabled()) {
      return _passThrough(request);
    }

    final userId = userIdFromAuthorization(request.headers['authorization']);
    if (userId == null) return _sendWithoutLogin(request);

    final key = cacheKeyFor(method: request.method, url: request.url, headers: request.headers);
    final cached = await _store.read(userId, key);

    final live = _fetchAndKeep(request, userId, key);
    // If the answer comes after we stopped waiting, nobody listens to it: a
    // failure then must not be reported as an error that nobody handled.
    live.ignore();

    try {
      return cached == null ? await live : await live.timeout(_slowAfter);
    } on TimeoutException {
      // Either we stopped waiting (there is a copy), or the connection itself
      // timed out (there may be no copy).
      _status.markOffline();
      if (cached == null) rethrow;
      return _fromCache(request, cached);
    } catch (error) {
      if (!_isNetworkError(error)) rethrow;
      _status.markOffline();
      if (cached == null) rethrow;
      return _fromCache(request, cached);
    }
  }

  /// A read that carries no signed-in user. When the phone remembers who was
  /// signed in and has a copy of this read, the copy answers: without the login
  /// the server would hide the data (the rules of the database), so its answer
  /// would be empty. A try to bring the login back starts in the background,
  /// and nothing is kept from an answer given without a login.
  Future<http.StreamedResponse> _sendWithoutLogin(http.BaseRequest request) async {
    String? userId;
    try {
      userId = await _rememberedUserId?.call();
    } catch (_) {
      userId = null;
    }
    if (userId == null) return _passThrough(request);

    final key = cacheKeyFor(method: request.method, url: request.url, headers: request.headers);
    final cached = await _store.read(userId, key);
    if (cached == null) return _passThrough(request);

    final restore = _restoreSession;
    if (restore != null) {
      unawaited(restore().then((_) {}, onError: (_) {}));
    }
    return _fromCache(request, cached);
  }

  /// Anything that is not a read of a signed-in user goes to the server as it is.
  Future<http.StreamedResponse> _passThrough(http.BaseRequest request) async {
    try {
      final response = await _inner.send(request);
      _status.markOnline();
      return response;
    } catch (error) {
      if (_isNetworkError(error)) _status.markOffline();
      rethrow;
    }
  }

  Future<http.StreamedResponse> _fetchAndKeep(
    http.BaseRequest request,
    String userId,
    String key,
  ) async {
    final response = await _inner.send(request);
    final bytes = await response.stream.toBytes();
    _status.markOnline();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // The screen does not wait for the disk.
      unawaited(_keep(userId, key, response, bytes));
    }

    return http.StreamedResponse(
      http.ByteStream.fromBytes(bytes),
      response.statusCode,
      contentLength: bytes.length,
      request: request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  Future<void> _keep(String userId, String key, http.StreamedResponse response, List<int> bytes) async {
    try {
      await _store.write(
        userId,
        key,
        CachedResponse(
          statusCode: response.statusCode,
          headers: {
            for (final name in _headersKept)
              if (response.headers[name] != null) name: response.headers[name]!,
          },
          body: utf8.decode(bytes),
          savedAt: _clock(),
        ),
      );
    } catch (_) {
      // A copy that could not be kept (disk full, an answer that is not text)
      // only means there is no copy: the screen already has its answer.
    }
  }

  http.StreamedResponse _fromCache(http.BaseRequest request, CachedResponse cached) {
    final bytes = utf8.encode(cached.body);
    _status.markServedFromCache(cached.savedAt);

    return http.StreamedResponse(
      http.ByteStream.fromBytes(bytes),
      cached.statusCode,
      contentLength: bytes.length,
      request: request,
      headers: {...cached.headers, 'x-finly-cache': 'hit'},
    );
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
