import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/usecases/create_account_use_case.dart';
import 'package:finly/features/accounts/presentation/cubit/account_form_cubit.dart';
import 'package:finly/features/accounts/presentation/cubit/account_form_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCreateAccount extends Mock implements CreateAccountUseCase {}

void main() {
  late MockCreateAccount createAccount;

  const params = CreateAccountParams(
    workspaceId: 'w1',
    name: 'Nubank',
    type: AccountType.checking,
    currency: 'BRL',
    openingBalanceCents: 100000,
  );
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

  setUp(() => createAccount = MockCreateAccount());

  Future<void> submit(AccountFormCubit cubit) => cubit.submit(
        workspaceId: 'w1',
        name: 'Nubank',
        type: AccountType.checking,
        currency: 'BRL',
        openingBalanceCents: 100000,
      );

  blocTest<AccountFormCubit, AccountFormState>(
    'emits submitting then success with the account',
    build: () {
      when(() => createAccount(params)).thenAnswer(
        (_) async => const Right<Failure, AccountEntity>(account),
      );
      return AccountFormCubit(createAccount);
    },
    act: submit,
    expect: () => [
      const AccountFormState(status: AccountFormStatus.submitting),
      const AccountFormState(
        status: AccountFormStatus.success,
        account: account,
      ),
    ],
  );

  blocTest<AccountFormCubit, AccountFormState>(
    'emits submitting then failure with the reason',
    build: () {
      when(() => createAccount(params)).thenAnswer(
        (_) async => const Left<Failure, AccountEntity>(
          ConflictFailure('already_exists'),
        ),
      );
      return AccountFormCubit(createAccount);
    },
    act: submit,
    expect: () => [
      const AccountFormState(status: AccountFormStatus.submitting),
      const AccountFormState(
        status: AccountFormStatus.failure,
        failure: ConflictFailure('already_exists'),
      ),
    ],
  );

  blocTest<AccountFormCubit, AccountFormState>(
    'calls the use case once with what the form sent',
    build: () {
      when(() => createAccount(params)).thenAnswer(
        (_) async => const Right<Failure, AccountEntity>(account),
      );
      return AccountFormCubit(createAccount);
    },
    act: submit,
    verify: (_) => verify(() => createAccount(params)).called(1),
  );
}