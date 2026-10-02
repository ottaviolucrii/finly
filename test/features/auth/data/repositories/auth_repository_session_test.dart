import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:finly/features/auth/data/models/user_model.dart';
import 'package:finly/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

  group('getCurrentUser', () {
    test('returns the user when a session exists', () async {
      when(() => remote.currentUser()).thenAnswer((_) async => user);

      final result = await repository.getCurrentUser();

      expect(result, const Right<Failure, UserEntity?>(user));
    });

    test('returns null when nobody is signed in', () async {
      when(() => remote.currentUser()).thenAnswer((_) async => null);

      final result = await repository.getCurrentUser();

      expect(result, const Right<Failure, UserEntity?>(null));
    });

    test('maps a timeout to NetworkFailure', () async {
      when(() => remote.currentUser()).thenThrow(TimeoutException('slow'));

      final result = await repository.getCurrentUser();

      expect(
        result,
        const Left<Failure, UserEntity?>(NetworkFailure('network_error')),
      );
    });
  });
}