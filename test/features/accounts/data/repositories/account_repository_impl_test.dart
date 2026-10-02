import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/data/datasources/account_remote_data_source.dart';
import 'package:finly/features/accounts/data/models/account_model.dart';
import 'package:finly/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockRemote extends Mock implements AccountRemoteDataSource {}

void main() {
  late MockRemote remote;
  late AccountRepositoryImpl repository;

  const model = AccountModel(
    id: 'a1',
    workspaceId: 'w1',
    name: 'Nubank',
    type: AccountType.checking,
    currency: 'BRL',
    openingBalanceCents: 100000,
    postedBalanceCents: 100000,
    projectedBalanceCents: 100000,
  );

  setUpAll(() => registerFallbackValue(AccountType.checking));

  setUp(() {
    remote = MockRemote();
    repository = AccountRepositoryImpl(remote);
  });

  Future<Either<Failure, AccountEntity>> create() {
    return repository.createAccount(
      workspaceId: 'w1',
      name: 'Nubank',
      type: AccountType.checking,
      currency: 'BRL',
      openingBalanceCents: 100000,
    );
  }

  test('getAccounts returns the accounts', () async {
    when(() => remote.getAccounts('w1')).thenAnswer((_) async => [model]);

    final result = await repository.getAccounts('w1');

    result.fold(
      (failure) => fail('expected accounts, got $failure'),
      (accounts) => expect(accounts, [model]),
    );
  });

  test('createAccount returns the created account', () async {
    when(() => remote.createAccount(
          workspaceId: any(named: 'workspaceId'),
          name: any(named: 'name'),
          type: any(named: 'type'),
          currency: any(named: 'currency'),
          openingBalanceCents: any(named: 'openingBalanceCents'),
        )).thenAnswer((_) async => model);

    expect(await create(), const Right<Failure, AccountEntity>(model));
  });

  test('a duplicate name becomes ConflictFailure', () async {
    when(() => remote.createAccount(
          workspaceId: any(named: 'workspaceId'),
          name: any(named: 'name'),
          type: any(named: 'type'),
          currency: any(named: 'currency'),
          openingBalanceCents: any(named: 'openingBalanceCents'),
        )).thenThrow(
      PostgrestException(message: 'duplicate key value', code: '23505'),
    );

    expect(
      await create(),
      const Left<Failure, AccountEntity>(ConflictFailure('already_exists')),
    );
  });

  test('archiveAccount succeeds', () async {
    when(() => remote.archiveAccount('a1')).thenAnswer((_) async {});

    final result = await repository.archiveAccount('a1');

    expect(result.isRight(), isTrue);
    verify(() => remote.archiveAccount('a1')).called(1);
  });

  test('a timeout becomes NetworkFailure', () async {
    when(() => remote.getAccounts('w1')).thenThrow(TimeoutException('slow'));

    final result = await repository.getAccounts('w1');

    expect(
      result,
      const Left<Failure, List<AccountEntity>>(NetworkFailure('network_error')),
    );
  });
}