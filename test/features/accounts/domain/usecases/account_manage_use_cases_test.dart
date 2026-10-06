import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/repositories/account_repository.dart';
import 'package:finly/features/accounts/domain/usecases/get_archived_accounts_use_case.dart';
import 'package:finly/features/accounts/domain/usecases/restore_account_use_case.dart';
import 'package:finly/features/accounts/domain/usecases/update_account_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAccountRepository extends Mock implements AccountRepository {}

void main() {
  late MockAccountRepository repository;

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

  setUp(() => repository = MockAccountRepository());

  group('GetArchivedAccountsUseCase', () {
    test('rejects an empty workspace id', () async {
      final result = await GetArchivedAccountsUseCase(repository)(' ');

      expect(
        result,
        const Left<Failure, List<AccountEntity>>(
          ValidationFailure('invalid_workspace'),
        ),
      );
      verifyNever(() => repository.getArchivedAccounts(any()));
    });

    test('returns the archived accounts', () async {
      when(() => repository.getArchivedAccounts('w1')).thenAnswer(
        (_) async => const Right<Failure, List<AccountEntity>>([account]),
      );

      final result = await GetArchivedAccountsUseCase(repository)('w1');

      expect(result.isRight(), isTrue);
    });
  });

  group('UpdateAccountUseCase', () {
    test('rejects a missing id', () async {
      final result = await UpdateAccountUseCase(repository)(
        const UpdateAccountParams(accountId: ' ', name: 'Nubank'),
      );

      expect(
        result,
        const Left<Failure, AccountEntity>(ValidationFailure('invalid_account')),
      );
    });

    test('rejects an empty or too long name', () async {
      final useCase = UpdateAccountUseCase(repository);

      expect(
        await useCase(const UpdateAccountParams(accountId: 'a1', name: '  ')),
        const Left<Failure, AccountEntity>(
          ValidationFailure('invalid_account_name'),
        ),
      );
      expect(
        await useCase(UpdateAccountParams(accountId: 'a1', name: 'a' * 81)),
        const Left<Failure, AccountEntity>(
          ValidationFailure('invalid_account_name'),
        ),
      );
      verifyNever(() => repository.updateAccount(
            accountId: any(named: 'accountId'),
            name: any(named: 'name'),
            openingBalanceCents: any(named: 'openingBalanceCents'),
          ));
    });

    test('trims the name and forwards the opening balance', () async {
      when(() => repository.updateAccount(
            accountId: 'a1',
            name: 'Nubank Empresa',
            openingBalanceCents: 250000,
          )).thenAnswer((_) async => const Right<Failure, AccountEntity>(account));

      final result = await UpdateAccountUseCase(repository)(
        const UpdateAccountParams(
          accountId: 'a1',
          name: '  Nubank Empresa ',
          openingBalanceCents: 250000,
        ),
      );

      expect(result.isRight(), isTrue);
    });

    test('leaves the opening balance alone when none is given', () async {
      when(() => repository.updateAccount(
            accountId: 'a1',
            name: 'Visa',
            openingBalanceCents: null,
          )).thenAnswer((_) async => const Right<Failure, AccountEntity>(account));

      final result = await UpdateAccountUseCase(repository)(
        const UpdateAccountParams(accountId: 'a1', name: 'Visa'),
      );

      expect(result.isRight(), isTrue);
    });

    test('passes a repository failure through unchanged', () async {
      when(() => repository.updateAccount(
            accountId: any(named: 'accountId'),
            name: any(named: 'name'),
            openingBalanceCents: any(named: 'openingBalanceCents'),
          )).thenAnswer(
        (_) async => const Left<Failure, AccountEntity>(
          ConflictFailure('already_exists'),
        ),
      );

      final result = await UpdateAccountUseCase(repository)(
        const UpdateAccountParams(accountId: 'a1', name: 'Nubank'),
      );

      expect(
        result,
        const Left<Failure, AccountEntity>(ConflictFailure('already_exists')),
      );
    });
  });

  group('RestoreAccountUseCase', () {
    test('rejects an empty id', () async {
      final result = await RestoreAccountUseCase(repository)(' ');

      expect(
        result,
        const Left<Failure, void>(ValidationFailure('invalid_account')),
      );
      verifyNever(() => repository.restoreAccount(any()));
    });

    test('restores the account', () async {
      when(() => repository.restoreAccount('a1'))
          .thenAnswer((_) async => const Right<Failure, void>(null));

      final result = await RestoreAccountUseCase(repository)('a1');

      expect(result.isRight(), isTrue);
      verify(() => repository.restoreAccount('a1')).called(1);
    });
  });
}