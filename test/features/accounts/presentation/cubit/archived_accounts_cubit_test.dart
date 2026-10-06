import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/usecases/get_archived_accounts_use_case.dart';
import 'package:finly/features/accounts/domain/usecases/restore_account_use_case.dart';
import 'package:finly/features/accounts/presentation/cubit/archived_accounts_cubit.dart';
import 'package:finly/features/accounts/presentation/cubit/archived_accounts_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetArchived extends Mock implements GetArchivedAccountsUseCase {}

class MockRestore extends Mock implements RestoreAccountUseCase {}

void main() {
  late MockGetArchived getArchived;
  late MockRestore restore;

  const account = AccountEntity(
    id: 'a1',
    workspaceId: 'w1',
    name: 'Conta antiga',
    type: AccountType.savings,
    currency: 'BRL',
    openingBalanceCents: 0,
    postedBalanceCents: 0,
    projectedBalanceCents: 0,
  );

  setUp(() {
    getArchived = MockGetArchived();
    restore = MockRestore();
    when(() => getArchived('w1')).thenAnswer(
      (_) async => const Right<Failure, List<AccountEntity>>([account]),
    );
  });

  ArchivedAccountsCubit buildCubit() =>
      ArchivedAccountsCubit(getArchived: getArchived, restore: restore);

  blocTest<ArchivedAccountsCubit, ArchivedAccountsState>(
    'load emits loading then the archived accounts',
    build: buildCubit,
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const ArchivedAccountsState(status: ArchivedAccountsStatus.loading),
      const ArchivedAccountsState(
        status: ArchivedAccountsStatus.loaded,
        accounts: [account],
      ),
    ],
  );

  blocTest<ArchivedAccountsCubit, ArchivedAccountsState>(
    'load emits loading then failure',
    build: () {
      when(() => getArchived('w1')).thenAnswer(
        (_) async => const Left<Failure, List<AccountEntity>>(
          NetworkFailure('network_error'),
        ),
      );
      return buildCubit();
    },
    act: (cubit) => cubit.load('w1'),
    expect: () => [
      const ArchivedAccountsState(status: ArchivedAccountsStatus.loading),
      const ArchivedAccountsState(
        status: ArchivedAccountsStatus.failure,
        failure: NetworkFailure('network_error'),
      ),
    ],
  );

  test('restoring works, reloads the list and returns true', () async {
    when(() => restore('a1'))
        .thenAnswer((_) async => const Right<Failure, void>(null));
    final cubit = buildCubit();
    await cubit.load('w1');

    final restored = await cubit.restore(account);

    expect(restored, isTrue);
    verify(() => restore('a1')).called(1);
    verify(() => getArchived('w1')).called(2);
    await cubit.close();
  });

  test('a refused restore keeps the list, reports why and returns false',
      () async {
    when(() => restore('a1')).thenAnswer(
      (_) async =>
          const Left<Failure, void>(ConflictFailure('already_exists')),
    );
    final cubit = buildCubit();
    await cubit.load('w1');

    final restored = await cubit.restore(account);

    expect(restored, isFalse);
    expect(cubit.state.accounts, [account]);
    expect(cubit.state.actionFailure, const ConflictFailure('already_exists'));
    await cubit.close();
  });

  blocTest<ArchivedAccountsCubit, ArchivedAccountsState>(
    'reload does nothing before the first load',
    build: buildCubit,
    act: (cubit) => cubit.reload(),
    expect: () => <ArchivedAccountsState>[],
    verify: (_) => verifyNever(() => getArchived(any())),
  );
}