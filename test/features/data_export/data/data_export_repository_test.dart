import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/data_export/data/datasources/data_export_remote_data_source.dart';
import 'package:finly/features/data_export/data/repositories/data_export_repository_impl.dart';
import 'package:finly/features/data_export/domain/entities/user_data_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements DataExportRemoteDataSource {}

void main() {
  late MockRemote remote;
  late DataExportRepositoryImpl repository;

  setUp(() {
    remote = MockRemote();
    repository = DataExportRepositoryImpl(remote);
  });

  test('returns what the data source read', () async {
    const snapshot = UserDataSnapshot(userId: 'u1', email: 'a@b.com');
    when(() => remote.readAll()).thenAnswer((_) async => snapshot);

    final result = await repository.readAll();

    expect(result, const Right<Failure, UserDataSnapshot>(snapshot));
  });

  test('a session that is gone becomes a failure', () async {
    when(() => remote.readAll()).thenThrow(const AuthException('not_authenticated'));

    final result = await repository.readAll();

    expect(result.isLeft(), isTrue);
  });

  test('a timeout becomes NetworkFailure', () async {
    when(() => remote.readAll()).thenThrow(TimeoutException('slow'));

    final result = await repository.readAll();

    expect(result, const Left<Failure, UserDataSnapshot>(NetworkFailure('network_error')));
  });

  test('an unexpected error becomes a failure instead of escaping', () async {
    when(() => remote.readAll()).thenThrow(StateError('boom'));

    final result = await repository.readAll();

    expect(result, const Left<Failure, UserDataSnapshot>(ServerFailure('unknown_error')));
  });
}
