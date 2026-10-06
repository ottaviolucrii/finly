import 'dart:io';

import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a bug (a StateError) becomes a generic failure', () {
    expect(
      ErrorMapper.toFailure(StateError('boom')),
      const ServerFailure('unknown_error'),
    );
  });

  test('a type error becomes a generic failure too', () {
    Object? caught;
    try {
      // A cast that fails at runtime, like the ones that froze a screen once.
      final Object value = 'text';
      value as int;
    } catch (e) {
      caught = e;
    }

    expect(caught, isNotNull);
    expect(
      ErrorMapper.toFailure(caught!),
      const ServerFailure('unknown_error'),
    );
  });

  test('no connection becomes a network failure', () {
    expect(
      ErrorMapper.toFailure(const SocketException('Failed host lookup')),
      const NetworkFailure('network_error'),
    );
  });

  test('a broken TLS handshake becomes a network failure', () {
    expect(
      ErrorMapper.toFailure(const HandshakeException('handshake failed')),
      const NetworkFailure('network_error'),
    );
  });
}