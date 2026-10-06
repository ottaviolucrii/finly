import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/usecases/update_account_use_case.dart';
import 'package:finly/features/accounts/presentation/cubit/account_edit_cubit.dart';
import 'package:finly/features/accounts/presentation/cubit/account_edit_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUpdateAccount extends Mock implements UpdateAccountUseCase {}

void main() {
  late MockUpdateAccount updateAccount;

  const params = UpdateAccountParams(
    accountId: 'a1',
    name: 'Nubank Empresa',
    openingBalanceCents: 250000,
  );
  const account = AccountEntity(
    id: 'a1',
    workspaceId: 'w1',
    name: 'Nubank Empresa',
    type: AccountType.checking,
    currency: 'BRL',
    openingBalanceCents: 250000,
    postedBalanceCents: 250000,
    projectedBalanceCents: 250000,
  );

  setUp(() => updateAccount = MockUpdateAccount());

  Future<void> submit(AccountEditCubit cubit) => cubit.submit(
        accountId: 'a1',
        name: 'Nubank Empresa',
        openingBalanceCents: 250000,
      );

  blocTest<AccountEditCubit, AccountEditState>(
    'emits submitting then success',
    build: () {
      when(() => updateAccount(params))
          .thenAnswer((_) async => const Right<Failure, AccountEntity>(account));
      return AccountEditCubit(updateAccount);
    },
    act: submit,
    expect: () => [
      const AccountEditState(status: AccountEditStatus.submitting),
      const AccountEditState(status: AccountEditStatus.success),
    ],
  );

  blocTest<AccountEditCubit, AccountEditState>(
    'emits submitting then failure with the reason',
    build: () {
      when(() => updateAccount(params)).thenAnswer(
        (_) async => const Left<Failure, AccountEntity>(
          ConflictFailure('already_exists'),
        ),
      );
      return AccountEditCubit(updateAccount);
    },
    act: submit,
    expect: () => [
      const AccountEditState(status: AccountEditStatus.submitting),
      const AccountEditState(
        status: AccountEditStatus.failure,
        failure: ConflictFailure('already_exists'),
      ),
    ],
  );

  blocTest<AccountEditCubit, AccountEditState>(
    'calls the use case once with what the form sent',
    build: () {
      when(() => updateAccount(params))
          .thenAnswer((_) async => const Right<Failure, AccountEntity>(account));
      return AccountEditCubit(updateAccount);
    },
    act: submit,
    verify: (_) => verify(() => updateAccount(params)).called(1),
  );
}