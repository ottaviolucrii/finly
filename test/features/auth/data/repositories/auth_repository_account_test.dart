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

  group('changePassword', () {
    test('succeeds', () async {
      when(() => remote.changePassword(
            currentPassword: 'senhaAtual1',
            newPassword: 'novaSenha2',
          )).thenAnswer((_) async {});

      final result = await repository.changePassword(
        currentPassword: 'senhaAtual1',
        newPassword: 'novaSenha2',
      );

      expect(result.isRight(), isTrue);
    });

    test('a wrong current password becomes AuthFailure', () async {
      when(() => remote.changePassword(
            currentPassword: any(named: 'currentPassword'),
            newPassword: any(named: 'newPassword'),
          )).thenThrow(const AuthException('Invalid login credentials'));

      final result = await repository.changePassword(
        currentPassword: 'errada123',
        newPassword: 'novaSenha2',
      );

      expect(
        result,
        const Left<Failure, void>(AuthFailure('invalid_credentials')),
      );
    });

    test('a timeout becomes NetworkFailure', () async {
      when(() => remote.changePassword(
            currentPassword: any(named: 'currentPassword'),
            newPassword: any(named: 'newPassword'),
          )).thenThrow(TimeoutException('slow'));

      final result = await repository.changePassword(
        currentPassword: 'senhaAtual1',
        newPassword: 'novaSenha2',
      );

      expect(
        result,
        const Left<Failure, void>(NetworkFailure('network_error')),
      );
    });
  });

  group('deleteAccount', () {
    test('succeeds', () async {
      when(() => remote.deleteAccount(password: 'senha123'))
          .thenAnswer((_) async {});

      final result = await repository.deleteAccount(password: 'senha123');

      expect(result.isRight(), isTrue);
      verify(() => remote.deleteAccount(password: 'senha123')).called(1);
    });

    test('a wrong password becomes AuthFailure and nothing is deleted',
        () async {
      when(() => remote.deleteAccount(password: any(named: 'password')))
          .thenThrow(const AuthException('Invalid login credentials'));

      final result = await repository.deleteAccount(password: 'errada123');

      expect(
        result,
        const Left<Failure, void>(AuthFailure('invalid_credentials')),
      );
    });

    test('a database refusal becomes a Failure', () async {
      when(() => remote.deleteAccount(password: any(named: 'password')))
          .thenThrow(PostgrestException(message: 'forbidden', code: '42501'));

      final result = await repository.deleteAccount(password: 'senha123');

      expect(
        result,
        const Left<Failure, void>(PermissionFailure('forbidden')),
      );
    });
  });
}