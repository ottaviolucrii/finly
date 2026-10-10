import 'dart:convert';

/// The headers that change what the server answers to the same address: the
/// shape of the answer (a list or one row), the page, and the schema.
const List<String> _headersOfTheKey = [
  'accept',
  'range',
  'range-unit',
  'prefer',
  'accept-profile',
  'content-profile',
];

/// The user a request is made for, read from the `sub` of the JWT in its
/// Authorization header. Null when there is no signed-in user (the public key
/// has no `sub`), or when the header is not a JWT.
String? userIdFromAuthorization(String? header) {
  if (header == null) return null;
  final parts = header.trim().split(RegExp(r'\s+'));
  final token = parts.length == 2 && parts.first.toLowerCase() == 'bearer' ? parts.last : null;
  if (token == null) return null;

  final segments = token.split('.');
  if (segments.length != 3) return null;

  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(segments[1])));
    final sub = (jsonDecode(payload) as Map<String, dynamic>)['sub'];
    return sub is String && sub.isNotEmpty ? sub : null;
  } catch (_) {
    return null;
  }
}

int _fnv1a32(String text, int seed) {
  var hash = seed;
  for (final unit in utf8.encode(text)) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// A name for the copy of one read: the same request gives the same name, and
/// a different one (another address, page or shape of answer) gives another.
/// 16 hex characters, safe for a file name.
String cacheKeyFor({
  required String method,
  required Uri url,
  required Map<String, String> headers,
}) {
  final lower = {for (final entry in headers.entries) entry.key.toLowerCase(): entry.value};

  final text = StringBuffer()
    ..writeln(method.toUpperCase())
    ..writeln(url.toString());
  for (final name in _headersOfTheKey) {
    text.writeln('$name=${lower[name] ?? ''}');
  }

  final value = text.toString();
  final first = _fnv1a32(value, 0x811C9DC5);
  final second = _fnv1a32(value, 0x050C5D1F);
  return first.toRadixString(16).padLeft(8, '0') + second.toRadixString(16).padLeft(8, '0');
}
