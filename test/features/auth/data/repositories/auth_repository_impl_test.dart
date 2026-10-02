import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:finly/features/auth/data/models/user_model.dart';
import 'package:finly/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:finly/features/auth/domain/entities/sign_up_result.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements AuthRemoteDataSource {}

void main() {
  late MockRemote remote;
  late AuthRepositoryImpl repository;

  const user = UserModel(
    id: 'u1',
    fullName: 'Ana Teste',
    email: 'ana@finly.com',
    workspaces: [],
  );

  setUp(() {
    remote = MockRemote();
    repository = AuthRepositoryImpl(remote);
  });

  group('signIn', () {
    test('returns the user on success', () async {
      when(() => remote.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => user);

      final result =
          await repository.signIn(email: 'ana@finly.com', password: 'secret123');

      expect(result, const Right<Failure, UserEntity>(user));
    });

    test('maps a wrong password to AuthFailure', () async {
      when(() => remote.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(AuthException('Invalid login credentials',
          code: 'invalid_credentials'));

      final result =
          await repository.signIn(email: 'ana@finly.com', password: 'wrong');

      expect(
        result,
        const Left<Failure, UserEntity>(AuthFailure('invalid_credentials')),
      );
    });

    test('maps a timeout to NetworkFailure', () async {
      when(() => remote.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(TimeoutException('slow'));

      final result =
          await repository.signIn(email: 'ana@finly.com', password: 'secret123');

      expect(
        result,
        const Left<Failure, UserEntity>(NetworkFailure('network_error')),
      );
    });
  });

  group('signUp', () {
    test('returns the sign-up result on success', () async {
      const signUpResult = SignUpResult(
        email: 'ana@finly.com',
        needsEmailVerification: true,
      );
      when(() => remote.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            fullName: any(named: 'fullName'),
          )).thenAnswer((_) async => signUpResult);

      final result = await repository.signUp(
        email: 'ana@finly.com',
        password: 'secret123',
        fullName: 'Ana Teste',
      );

      expect(result, const Right<Failure, SignUpResult>(signUpResult));
    });
  });

  group('signOut', () {
    test('passes allDevices to the data source', () async {
      when(() => remote.signOut(allDevices: true)).thenAnswer((_) async {});

      final result = await repository.signOut(allDevices: true);

      expect(result.isRight(), isTrue);
      verify(() => remote.signOut(allDevices: true)).called(1);
    });

    test('maps an unexpected exception to ServerFailure', () async {
      when(() => remote.signOut(allDevices: false)).thenThrow(Exception('boom'));

      final result = await repository.signOut();

      expect(
        result,
        const Left<Failure, void>(ServerFailure('unknown_error')),
      );
    });
  });

  group('switchWorkspace', () {
    test('returns the refreshed user', () async {
      when(() => remote.switchWorkspace('w1')).thenAnswer((_) async => user);

      final result = await repository.switchWorkspace('w1');

      expect(result, const Right<Failure, UserEntity>(user));
    });

    test('maps forbidden to PermissionFailure', () async {
      when(() => remote.switchWorkspace('w2')).thenThrow(
        PostgrestException(message: 'forbidden', code: '42501'),
      );

      final result = await repository.switchWorkspace('w2');

      expect(
        result,
        const Left<Failure, UserEntity>(PermissionFailure('forbidden')),
      );
    });
  });
}