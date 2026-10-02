import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/repositories/account_repository.dart';
import 'package:finly/features/accounts/domain/usecases/create_account_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAccountRepository extends Mock implements AccountRepository {}

void main() {
  late MockAccountRepository repository;
  late CreateAccountUseCase useCase;

  const account = AccountEntity(
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
    repository = MockAccountRepository();
    useCase = CreateAccountUseCase(repository);
  });

  CreateAccountParams params({
    String name = 'Nubank',
    AccountType type = AccountType.checking,
    String currency = 'BRL',
  }) {
    return CreateAccountParams(
      workspaceId: 'w1',
      name: name,
      type: type,
      currency: currency,
      openingBalanceCents: 100000,
    );
  }

  void verifyRepositoryNotCalled() {
    verifyNever(() => repository.createAccount(
          workspaceId: any(named: 'workspaceId'),
          name: any(named: 'name'),
          type: any(named: 'type'),
          currency: any(named: 'currency'),
          openingBalanceCents: any(named: 'openingBalanceCents'),
        ));
  }

  Future<void> expectRejected(CreateAccountParams p, String code) async {
    final result = await useCase(p);
    expect(result, Left<Failure, AccountEntity>(ValidationFailure(code)));
    verifyRepositoryNotCalled();
  }

  test('rejects an empty name', () async {
    await expectRejected(params(name: '   '), 'invalid_account_name');
  });

  test('rejects a name longer than 80 characters', () async {
    await expectRejected(params(name: 'a' * 81), 'invalid_account_name');
  });

  test('rejects an unsupported currency', () async {
    await expectRejected(params(currency: 'GBP'), 'invalid_currency');
  });

  test('rejects credit cards until they have their own flow', () async {
    await expectRejected(
      params(type: AccountType.creditCard),
      'credit_card_needs_settings',
    );
  });

  test('trims the name and forwards the account to the repository', () async {
    when(() => repository.createAccount(
          workspaceId: 'w1',
          name: 'Nubank',
          type: AccountType.checking,
          currency: 'BRL',
          openingBalanceCents: 100000,
        )).thenAnswer((_) async => const Right<Failure, AccountEntity>(account));

    final result = await useCase(params(name: '  Nubank '));

    expect(result, const Right<Failure, AccountEntity>(account));
  });

  test('passes a repository failure through unchanged', () async {
    when(() => repository.createAccount(
          workspaceId: any(named: 'workspaceId'),
          name: any(named: 'name'),
          type: any(named: 'type'),
          currency: any(named: 'currency'),
          openingBalanceCents: any(named: 'openingBalanceCents'),
        )).thenAnswer(
      (_) async =>
          const Left<Failure, AccountEntity>(ConflictFailure('already_exists')),
    );

    final result = await useCase(params());

    expect(
      result,
      const Left<Failure, AccountEntity>(ConflictFailure('already_exists')),
    );
  });
}