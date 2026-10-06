import 'package:finly/core/error/error_mapper.dart';
import 'package:finly/core/error/failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('an expired or wrong one-time code (by code) becomes invalid_code', () {
    expect(
      ErrorMapper.toFailure(const AuthException('x', code: 'otp_expired')),
      const AuthFailure('invalid_code'),
    );
  });

  test('an expired or wrong one-time code (by message) becomes invalid_code', () {
    expect(
      ErrorMapper.toFailure(
        const AuthException('Token has expired or is invalid'),
      ),
      const AuthFailure('invalid_code'),
    );
  });

  test('a new password equal to the old one becomes same_password', () {
    expect(
      ErrorMapper.toFailure(
        const AuthException(
          'New password should be different from the old password.',
          code: 'same_password',
        ),
      ),
      const ValidationFailure('same_password'),
    );
  });

  test('other auth errors still become auth_error', () {
    expect(
      ErrorMapper.toFailure(const AuthException('something else')),
      const AuthFailure('auth_error'),
    );
  });
}