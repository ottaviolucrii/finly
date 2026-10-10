import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/data/datasources/transaction_move_remote_data_source.dart';
import 'package:finly/features/transactions/data/repositories/transaction_move_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements TransactionMoveRemoteDataSource {}

void main() {
  late MockRemote remote;
  late TransactionMoveRepositoryImpl repository;

  setUp(() {
    remote = MockRemote();
    repository = TransactionMoveRepositoryImpl(remote);
  });

  test('succeeds when the data source does', () async {
    when(() => remote.moveTransaction('t1', 'a2')).thenAnswer((_) async {});

    final result = await repository.moveTransaction('t1', 'a2');

    expect(result.isRight(), isTrue);
    verify(() => remote.moveTransaction('t1', 'a2')).called(1);
  });

  test('a refusal of the database becomes RuleFailure with the reason', () async {
    when(() => remote.moveTransaction(any(), any())).thenThrow(
      PostgrestException(message: 'a card purchase cannot be moved', code: '23514'),
    );

    final result = await repository.moveTransaction('t1', 'a2');

    expect(
      result,
      const Left<Failure, void>(RuleFailure('a card purchase cannot be moved')),
    );
  });

  test("someone else's transaction becomes PermissionFailure", () async {
    when(() => remote.moveTransaction(any(), any()))
        .thenThrow(PostgrestException(message: 'forbidden', code: '42501'));

    final result = await repository.moveTransaction('t1', 'a2');

    expect(result, const Left<Failure, void>(PermissionFailure('forbidden')));
  });

  test('a timeout becomes NetworkFailure', () async {
    when(() => remote.moveTransaction(any(), any())).thenThrow(TimeoutException('slow'));

    final result = await repository.moveTransaction('t1', 'a2');

    expect(result, const Left<Failure, void>(NetworkFailure('network_error')));
  });

  test('an unexpected error becomes a failure instead of escaping', () async {
    when(() => remote.moveTransaction(any(), any())).thenThrow(StateError('boom'));

    final result = await repository.moveTransaction('t1', 'a2');

    expect(result, const Left<Failure, void>(ServerFailure('unknown_error')));
  });
}
