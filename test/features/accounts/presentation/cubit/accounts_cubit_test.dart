import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/usecases/archive_account_use_case.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/accounts/presentation/cubit/accounts_cubit.dart';
import 'package:finly/features/accounts/presentation/cubit/accounts_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAccounts extends Mock implements GetAccountsUseCase {}

class MockArchiveAccount extends Mock implements ArchiveAccountUseCase {}

void main() {
  late MockGetAccounts getAccounts;
  late MockArchiveAccount archiveAccount;

  const first = AccountEntity(
    id: 'a1',
    workspaceId: 'w1',
    name: 'Nubank',
    type: AccountType.checking,
    currency: 'BRL',
    openingBalanceCents: 100000,
    postedBalanceCents: 100000,
    projectedBalanceCents: 100000,
  );
  const second = AccountEntity(
    id: 'a2',
    workspaceId: 'w1',
    name: 'Poupança',
    type: AccountType.savings,
    currency: 'BRL',
    openingBalanceCents: 5000,
    postedBalanceCents: 5000,
    projectedBalanceCents: 5000,
  );

  setUp(() {
    getAccounts = MockGetAccounts();
    archiveAccount = MockArchiveAccount();
  });

  AccountsCubit buildCubit() => AccountsCubit(getAccounts, archiveAccount);

  blocTest<AccountsCubit, AccountsState>(
    'load emits loading then the accounts',
    build: () {
      when(() => getAccounts('w1')).thenAnswer(
        (_) async =>
            const Right<Failure, List<AccountEntity>>([first, second]),
      );
      return buildCubit();
    },
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const AccountsState(status: AccountsStatus.loading),
      const AccountsState(
        status: AccountsStatus.loaded,
        accounts: [first, second],
      ),
    ],
  );

  blocTest<AccountsCubit, AccountsState>(
    'load emits loading then failure',
    build: () {
      when(() => getAccounts('w1')).thenAnswer(
        (_) async => const Left<Failure, List<AccountEntity>>(
          NetworkFailure('network_error'),
        ),
      );
      return buildCubit();
    },
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const AccountsState(status: AccountsStatus.loading),
      const AccountsState(
        status: AccountsStatus.failure,
        failure: NetworkFailure('network_error'),
      ),
    ],
  );

  blocTest<AccountsCubit, AccountsState>(
    'archive removes the account from the list',
    build: () {
      when(() => archiveAccount('a1'))
          .thenAnswer((_) async => const Right<Failure, void>(null));
      return buildCubit();
    },
    seed: () => const AccountsState(
      status: AccountsStatus.loaded,
      accounts: [first, second],
    ),
    act: (cubit) => cubit.archive('a1'),
    expect: () => [
      const AccountsState(status: AccountsStatus.loaded, accounts: [second]),
    ],
  );

  blocTest<AccountsCubit, AccountsState>(
    'archive failure keeps the list and reports the reason',
    build: () {
      when(() => archiveAccount('a1')).thenAnswer(
        (_) async =>
            const Left<Failure, void>(PermissionFailure('forbidden')),
      );
      return buildCubit();
    },
    seed: () => const AccountsState(
      status: AccountsStatus.loaded,
      accounts: [first, second],
    ),
    act: (cubit) => cubit.archive('a1'),
    expect: () => [
      const AccountsState(
        status: AccountsStatus.loaded,
        accounts: [first, second],
        actionFailure: PermissionFailure('forbidden'),
      ),
    ],
  );
}