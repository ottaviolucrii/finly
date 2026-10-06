import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:finly/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements AuthRemoteDataSource {}

void main() {
  late MockRemote remote;
  late AuthRepositoryImpl repository;

  setUp(() {
    remote = MockRemote();
    repository = AuthRepositoryImpl(remote);
  });

  group('requestPasswordReset', () {
    test('succeeds', () async {
      when(() => remote.requestPasswordReset(email: 'ana@exemplo.com'))
          .thenAnswer((_) async {});

      final result =
          await repository.requestPasswordReset(email: 'ana@exemplo.com');

      expect(result.isRight(), isTrue);
    });

    test('too many requests becomes rate_limited', () async {
      when(() => remote.requestPasswordReset(email: any(named: 'email')))
          .thenThrow(
        const AuthException('slow down', code: 'over_email_send_rate_limit'),
      );

      final result =
          await repository.requestPasswordReset(email: 'ana@exemplo.com');

      expect(result, const Left<Failure, void>(AuthFailure('rate_limited')));
    });

    test('a timeout becomes NetworkFailure', () async {
      when(() => remote.requestPasswordReset(email: any(named: 'email')))
          .thenThrow(TimeoutException('slow'));

      final result =
          await repository.requestPasswordReset(email: 'ana@exemplo.com');

      expect(result, const Left<Failure, void>(NetworkFailure('network_error')));
    });
  });

  group('resetPassword', () {
    Future<Either<Failure, void>> reset() {
      return repository.resetPassword(
        email: 'ana@exemplo.com',
        code: '123456',
        newPassword: 'novaSenha2',
      );
    }

    test('succeeds', () async {
      when(() => remote.resetPassword(
            email: 'ana@exemplo.com',
            code: '123456',
            newPassword: 'novaSenha2',
          )).thenAnswer((_) async {});

      final result = await reset();

      expect(result.isRight(), isTrue);
    });

    test('a wrong or expired code becomes invalid_code', () async {
      when(() => remote.resetPassword(
            email: any(named: 'email'),
            code: any(named: 'code'),
            newPassword: any(named: 'newPassword'),
          )).thenThrow(const AuthException('Token has expired or is invalid'));

      final result = await reset();

      expect(result, const Left<Failure, void>(AuthFailure('invalid_code')));
    });

    test('a new password equal to the old one becomes same_password', () async {
      when(() => remote.resetPassword(
            email: any(named: 'email'),
            code: any(named: 'code'),
            newPassword: any(named: 'newPassword'),
          )).thenThrow(
        const AuthException('same', code: 'same_password'),
      );

      final result = await reset();

      expect(
        result,
        const Left<Failure, void>(ValidationFailure('same_password')),
      );
    });

    test('an unexpected error becomes a failure instead of escaping', () async {
      when(() => remote.resetPassword(
            email: any(named: 'email'),
            code: any(named: 'code'),
            newPassword: any(named: 'newPassword'),
          )).thenThrow(StateError('boom'));

      final result = await reset();

      expect(result, const Left<Failure, void>(ServerFailure('unknown_error')));
    });
  });
}