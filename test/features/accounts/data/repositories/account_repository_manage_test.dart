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

  setUp(() {
    remote = MockRemote();
    repository = AccountRepositoryImpl(remote);
  });

  test('getArchivedAccounts returns the archived accounts', () async {
    when(() => remote.getArchivedAccounts('w1')).thenAnswer((_) async => [model]);

    final result = await repository.getArchivedAccounts('w1');

    result.fold(
      (failure) => fail('expected accounts, got $failure'),
      (accounts) => expect(accounts, <AccountEntity>[model]),
    );
  });

  test('updateAccount returns the updated account', () async {
    when(() => remote.updateAccount(
          accountId: 'a1',
          name: 'Nubank Empresa',
          openingBalanceCents: 250000,
        )).thenAnswer((_) async => model);

    final result = await repository.updateAccount(
      accountId: 'a1',
      name: 'Nubank Empresa',
      openingBalanceCents: 250000,
    );

    expect(result, const Right<Failure, AccountEntity>(model));
  });

  test('renaming to a name already in use becomes ConflictFailure', () async {
    when(() => remote.updateAccount(
          accountId: any(named: 'accountId'),
          name: any(named: 'name'),
          openingBalanceCents: any(named: 'openingBalanceCents'),
        )).thenThrow(
      PostgrestException(message: 'duplicate key value', code: '23505'),
    );

    final result = await repository.updateAccount(
      accountId: 'a1',
      name: 'Conta Empresa1',
    );

    expect(
      result,
      const Left<Failure, AccountEntity>(ConflictFailure('already_exists')),
    );
  });

  test('restoring while the name is taken becomes ConflictFailure', () async {
    when(() => remote.restoreAccount('a1')).thenThrow(
      PostgrestException(message: 'duplicate key value', code: '23505'),
    );

    final result = await repository.restoreAccount('a1');

    expect(
      result,
      const Left<Failure, void>(ConflictFailure('already_exists')),
    );
  });

  test('restoreAccount succeeds', () async {
    when(() => remote.restoreAccount('a1')).thenAnswer((_) async {});

    final result = await repository.restoreAccount('a1');

    expect(result.isRight(), isTrue);
    verify(() => remote.restoreAccount('a1')).called(1);
  });

  test('a timeout becomes NetworkFailure', () async {
    when(() => remote.getArchivedAccounts('w1')).thenThrow(TimeoutException('slow'));

    final result = await repository.getArchivedAccounts('w1');

    result.fold(
      (failure) => expect(failure, const NetworkFailure('network_error')),
      (_) => fail('expected a failure'),
    );
  });
}