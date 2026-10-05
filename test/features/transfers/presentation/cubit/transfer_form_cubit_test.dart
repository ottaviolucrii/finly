import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/transfers/domain/entities/transfer_kind.dart';
import 'package:finly/features/transfers/domain/usecases/create_transfer_use_case.dart';
import 'package:finly/features/transfers/presentation/cubit/transfer_form_cubit.dart';
import 'package:finly/features/transfers/presentation/cubit/transfer_form_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAccounts extends Mock implements GetAccountsUseCase {}

class MockCreateTransfer extends Mock implements CreateTransferUseCase {}

void main() {
  late MockGetAccounts getAccounts;
  late MockCreateTransfer createTransfer;

  final occurredAt = DateTime(2026, 10, 2, 12);
  final params = CreateTransferParams(
    fromAccountId: 'a1',
    toAccountId: 'a9',
    fromCurrency: 'BRL',
    toCurrency: 'BRL',
    amountCents: 5000,
    description: 'Retirada',
    occurredAt: occurredAt,
    kind: TransferKind.ownerWithdrawal,
  );

  const otherAccount = AccountEntity(
    id: 'a9',
    workspaceId: 'w2',
    name: 'Conta pessoal',
    type: AccountType.checking,
    currency: 'BRL',
    openingBalanceCents: 0,
    postedBalanceCents: 0,
    projectedBalanceCents: 0,
  );

  setUp(() {
    getAccounts = MockGetAccounts();
    createTransfer = MockCreateTransfer();
  });

  TransferFormCubit buildCubit() => TransferFormCubit(getAccounts, createTransfer);

  Future<void> submit(TransferFormCubit cubit) => cubit.submit(
        fromAccountId: 'a1',
        toAccountId: 'a9',
        fromCurrency: 'BRL',
        toCurrency: 'BRL',
        amountCents: 5000,
        description: 'Retirada',
        occurredAt: occurredAt,
        kind: TransferKind.ownerWithdrawal,
      );

  blocTest<TransferFormCubit, TransferFormState>(
    'with no other workspace the form is ready at once',
    build: buildCubit,
    act: (cubit) => cubit.loadOtherAccounts(null),
    expect: () => [const TransferFormState(status: TransferFormStatus.ready)],
  );

  blocTest<TransferFormCubit, TransferFormState>(
    'loads the accounts of the other workspace',
    build: () {
      when(() => getAccounts('w2')).thenAnswer(
        (_) async =>
            const Right<Failure, List<AccountEntity>>([otherAccount]),
      );
      return buildCubit();
    },
    act: (cubit) => cubit.loadOtherAccounts('w2'),
    expect: () => [
      const TransferFormState(status: TransferFormStatus.loading),
      const TransferFormState(
        status: TransferFormStatus.ready,
        otherAccounts: [otherAccount],
      ),
    ],
  );

  blocTest<TransferFormCubit, TransferFormState>(
    'reports when the other workspace cannot be loaded',
    build: () {
      when(() => getAccounts('w2')).thenAnswer(
        (_) async => const Left<Failure, List<AccountEntity>>(
          NetworkFailure('network_error'),
        ),
      );
      return buildCubit();
    },
    act: (cubit) => cubit.loadOtherAccounts('w2'),
    expect: () => [
      const TransferFormState(status: TransferFormStatus.loading),
      const TransferFormState(
        status: TransferFormStatus.loadFailed,
        failure: NetworkFailure('network_error'),
      ),
    ],
  );

  blocTest<TransferFormCubit, TransferFormState>(
    'submit emits submitting then success and keeps the other accounts',
    build: () {
      when(() => createTransfer(params))
          .thenAnswer((_) async => const Right<Failure, String>('tr1'));
      return buildCubit();
    },
    seed: () => const TransferFormState(
      status: TransferFormStatus.ready,
      otherAccounts: [otherAccount],
    ),
    act: submit,
    expect: () => [
      const TransferFormState(
        status: TransferFormStatus.submitting,
        otherAccounts: [otherAccount],
      ),
      const TransferFormState(
        status: TransferFormStatus.success,
        otherAccounts: [otherAccount],
      ),
    ],
  );

  blocTest<TransferFormCubit, TransferFormState>(
    'submit emits submitting then failure with the reason',
    build: () {
      when(() => createTransfer(params)).thenAnswer(
        (_) async => const Left<Failure, String>(
          ValidationFailure('invalid_amount'),
        ),
      );
      return buildCubit();
    },
    seed: () => const TransferFormState(status: TransferFormStatus.ready),
    act: submit,
    expect: () => [
      const TransferFormState(status: TransferFormStatus.submitting),
      const TransferFormState(
        status: TransferFormStatus.failure,
        failure: ValidationFailure('invalid_amount'),
      ),
    ],
  );
}