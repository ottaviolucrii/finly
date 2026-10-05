import 'dart:async';

import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('auth errors', () {
    test('wrong credentials', () {
      final failure = ErrorMapper.toFailure(
        AuthException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      );
      expect(failure, const AuthFailure('invalid_credentials'));
    });

    test('falls back to the message when there is no code', () {
      expect(
        ErrorMapper.toFailure(AuthException('Email not confirmed')),
        const AuthFailure('email_not_confirmed'),
      );
    });

    test('e-mail already registered', () {
      expect(
        ErrorMapper.toFailure(
          AuthException('User already registered', code: 'user_already_exists'),
        ),
        const AuthFailure('email_already_registered'),
      );
    });

    test('weak password is a validation failure', () {
      expect(
        ErrorMapper.toFailure(
          AuthException('Password is too weak', code: 'weak_password'),
        ),
        const ValidationFailure('weak_password'),
      );
    });

    test('rate limit by status code', () {
      expect(
        ErrorMapper.toFailure(AuthException('Too many', statusCode: '429')),
        const AuthFailure('rate_limited'),
      );
    });

    test('unknown auth error', () {
      expect(
        ErrorMapper.toFailure(AuthException('something odd')),
        const AuthFailure('auth_error'),
      );
    });
  });

  group('database errors', () {
    test('invalid tax id', () {
      expect(
        ErrorMapper.toFailure(
          PostgrestException(message: 'invalid_tax_id', code: '22023'),
        ),
        const ValidationFailure('invalid_tax_id'),
      );
    });

    test('second workspace of the same type', () {
      expect(
        ErrorMapper.toFailure(
          PostgrestException(
            message: 'workspace_type_already_exists',
            code: '23505',
          ),
        ),
        const ConflictFailure('workspace_type_already_exists'),
      );
    });

    test('forbidden (RLS / ownership)', () {
      expect(
        ErrorMapper.toFailure(
          PostgrestException(message: 'forbidden', code: '42501'),
        ),
        const PermissionFailure('forbidden'),
      );
    });

    test('not authenticated', () {
      expect(
        ErrorMapper.toFailure(
          PostgrestException(message: 'not authenticated', code: '28000'),
        ),
        const AuthFailure('not_authenticated'),
      );
    });

    test('business rule from a trigger keeps its message', () {
      expect(
        ErrorMapper.toFailure(
          PostgrestException(message: 'invoice already paid', code: '23514'),
        ),
        const RuleFailure('invoice already paid'),
      );
    });

    test('unknown database code', () {
      expect(
        ErrorMapper.toFailure(PostgrestException(message: 'x', code: '99999')),
        const ServerFailure('server_error'),
      );
    });
  });

  group('other errors', () {
    test('timeout is a network failure', () {
      expect(
        ErrorMapper.toFailure(TimeoutException('slow')),
        const NetworkFailure('network_error'),
      );
    });

    test('anything else is an unknown server failure', () {
      expect(
        ErrorMapper.toFailure(Exception('boom')),
        const ServerFailure('unknown_error'),
      );
    });
  });
}