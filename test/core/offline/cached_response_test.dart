import 'package:finly/core/offline/cached_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final saved = DateTime(2026, 10, 9, 14, 32, 5);

  CachedResponse build({String body = '[{"id":1}]'}) {
    return CachedResponse(
      statusCode: 200,
      headers: const {'content-type': 'application/json; charset=utf-8', 'content-range': '0-0/1'},
      body: body,
      savedAt: saved,
    );
  }

  test('comes back the same after being written and read', () {
    final copy = build();

    expect(CachedResponse.fromJson(copy.toJson()), copy);
  });

  test('keeps accents and symbols of the data', () {
    final copy = build(body: '[{"name":"Mercadão R\$ 12,50 — café ☕"}]');

    expect(CachedResponse.fromJson(copy.toJson()).body, copy.body);
  });

  test('keeps the time of the copy to the second', () {
    expect(CachedResponse.fromJson(build().toJson()).savedAt, saved);
  });

  test('gives the time in local time', () {
    expect(CachedResponse.fromJson(build().toJson()).savedAt.isUtc, isFalse);
  });

  test('keeps a status that is not 200', () {
    final copy = CachedResponse(statusCode: 206, headers: const {}, body: '[]', savedAt: saved);

    expect(CachedResponse.fromJson(copy.toJson()).statusCode, 206);
  });

  test('text that is not a copy is an error', () {
    expect(() => CachedResponse.fromJson('not json'), throwsFormatException);
    expect(() => CachedResponse.fromJson('{"status":200}'), throwsA(isA<TypeError>()));
    expect(() => CachedResponse.fromJson('[]'), throwsA(isA<TypeError>()));
  });
}
