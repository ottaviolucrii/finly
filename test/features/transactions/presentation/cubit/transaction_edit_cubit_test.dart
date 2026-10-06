import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/domain/usecases/update_transaction_use_case.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_edit_cubit.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_edit_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUpdateTransaction extends Mock implements UpdateTransactionUseCase {}

void main() {
  late MockUpdateTransaction updateTransaction;

  final occurredAt = DateTime(2026, 10, 2, 12);
  final params = UpdateTransactionParams(
    transactionId: 't1',
    categoryId: 'c1',
    amountCents: 3000,
    description: 'Mercado',
    occurredAt: occurredAt,
    status: TransactionStatus.posted,
  );
  final updated = TransactionEntity(
    id: 't1',
    workspaceId: 'w1',
    accountId: 'a1',
    categoryId: 'c1',
    type: TransactionType.expense,
    status: TransactionStatus.posted,
    amountCents: 3000,
    currency: 'BRL',
    description: 'Mercado',
    occurredAt: occurredAt,
  );

  setUp(() => updateTransaction = MockUpdateTransaction());

  Future<void> submit(TransactionEditCubit cubit) => cubit.submit(
        transactionId: 't1',
        categoryId: 'c1',
        amountCents: 3000,
        description: 'Mercado',
        occurredAt: occurredAt,
        status: TransactionStatus.posted,
      );

  blocTest<TransactionEditCubit, TransactionEditState>(
    'emits submitting then success',
    build: () {
      when(() => updateTransaction(params)).thenAnswer(
        (_) async => Right<Failure, TransactionEntity>(updated),
      );
      return TransactionEditCubit(updateTransaction);
    },
    act: submit,
    expect: () => [
      const TransactionEditState(status: TransactionEditStatus.submitting),
      const TransactionEditState(status: TransactionEditStatus.success),
    ],
  );

  blocTest<TransactionEditCubit, TransactionEditState>(
    'emits submitting then failure with the reason',
    build: () {
      when(() => updateTransaction(params)).thenAnswer(
        (_) async => const Left<Failure, TransactionEntity>(
          RuleFailure('invoice already paid: its transactions are locked'),
        ),
      );
      return TransactionEditCubit(updateTransaction);
    },
    act: submit,
    expect: () => [
      const TransactionEditState(status: TransactionEditStatus.submitting),
      const TransactionEditState(
        status: TransactionEditStatus.failure,
        failure: RuleFailure('invoice already paid: its transactions are locked'),
      ),
    ],
  );

  blocTest<TransactionEditCubit, TransactionEditState>(
    'calls the use case once with what the form sent',
    build: () {
      when(() => updateTransaction(params)).thenAnswer(
        (_) async => Right<Failure, TransactionEntity>(updated),
      );
      return TransactionEditCubit(updateTransaction);
    },
    act: submit,
    verify: (_) => verify(() => updateTransaction(params)).called(1),
  );
}