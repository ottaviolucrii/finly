import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/domain/usecases/create_transaction_use_case.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_form_cubit.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_form_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCreateTransaction extends Mock implements CreateTransactionUseCase {}

void main() {
  late MockCreateTransaction createTransaction;

  final occurredAt = DateTime(2026, 10, 2, 12);
  final params = CreateTransactionParams(
    workspaceId: 'w1',
    accountId: 'a1',
    categoryId: 'c1',
    type: TransactionType.expense,
    status: TransactionStatus.posted,
    amountCents: 2500,
    currency: 'BRL',
    description: 'Mercado',
    occurredAt: occurredAt,
  );
  final transaction = TransactionEntity(
    id: 't1',
    workspaceId: 'w1',
    accountId: 'a1',
    categoryId: 'c1',
    type: TransactionType.expense,
    status: TransactionStatus.posted,
    amountCents: 2500,
    currency: 'BRL',
    description: 'Mercado',
    occurredAt: occurredAt,
  );

  setUp(() => createTransaction = MockCreateTransaction());

  Future<void> submit(TransactionFormCubit cubit) => cubit.submit(
        workspaceId: 'w1',
        accountId: 'a1',
        categoryId: 'c1',
        type: TransactionType.expense,
        status: TransactionStatus.posted,
        amountCents: 2500,
        currency: 'BRL',
        description: 'Mercado',
        occurredAt: occurredAt,
      );

  blocTest<TransactionFormCubit, TransactionFormState>(
    'emits submitting then success with the transaction',
    build: () {
      when(() => createTransaction(params)).thenAnswer(
        (_) async => Right<Failure, TransactionEntity>(transaction),
      );
      return TransactionFormCubit(createTransaction);
    },
    act: submit,
    expect: () => [
      const TransactionFormState(status: TransactionFormStatus.submitting),
      TransactionFormState(
        status: TransactionFormStatus.success,
        transaction: transaction,
      ),
    ],
  );

  blocTest<TransactionFormCubit, TransactionFormState>(
    'emits submitting then failure with the reason',
    build: () {
      when(() => createTransaction(params)).thenAnswer(
        (_) async => const Left<Failure, TransactionEntity>(
          ValidationFailure('invalid_amount'),
        ),
      );
      return TransactionFormCubit(createTransaction);
    },
    act: submit,
    expect: () => [
      const TransactionFormState(status: TransactionFormStatus.submitting),
      const TransactionFormState(
        status: TransactionFormStatus.failure,
        failure: ValidationFailure('invalid_amount'),
      ),
    ],
  );

  blocTest<TransactionFormCubit, TransactionFormState>(
    'calls the use case once with what the form sent',
    build: () {
      when(() => createTransaction(params)).thenAnswer(
        (_) async => Right<Failure, TransactionEntity>(transaction),
      );
      return TransactionFormCubit(createTransaction);
    },
    act: submit,
    verify: (_) => verify(() => createTransaction(params)).called(1),
  );
}