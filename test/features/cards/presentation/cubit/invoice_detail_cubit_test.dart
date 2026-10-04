import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/cards/domain/usecases/get_invoice_transactions_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/invoice_detail_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/invoice_detail_state.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetInvoiceTransactions extends Mock
    implements GetInvoiceTransactionsUseCase {}

void main() {
  late MockGetInvoiceTransactions getTransactions;

  final purchase = TransactionEntity(
    id: 't1',
    workspaceId: 'w1',
    accountId: 'a1',
    categoryId: null,
    type: TransactionType.expense,
    status: TransactionStatus.posted,
    amountCents: 10000,
    currency: 'BRL',
    description: 'Notebook',
    occurredAt: DateTime(2026, 3, 5, 12),
  );

  setUp(() => getTransactions = MockGetInvoiceTransactions());

  blocTest<InvoiceDetailCubit, InvoiceDetailState>(
    'load emits loading then the purchases',
    build: () {
      when(() => getTransactions('i1')).thenAnswer(
        (_) async => Right<Failure, List<TransactionEntity>>([purchase]),
      );
      return InvoiceDetailCubit(getTransactions);
    },
    act: (cubit) => cubit.load('i1'),
    expect: () => [
      const InvoiceDetailState(status: InvoiceDetailStatus.loading),
      InvoiceDetailState(
        status: InvoiceDetailStatus.loaded,
        transactions: [purchase],
      ),
    ],
  );

  blocTest<InvoiceDetailCubit, InvoiceDetailState>(
    'load emits loading then failure',
    build: () {
      when(() => getTransactions('i1')).thenAnswer(
        (_) async => const Left<Failure, List<TransactionEntity>>(
          NetworkFailure('network_error'),
        ),
      );
      return InvoiceDetailCubit(getTransactions);
    },
    act: (cubit) => cubit.load('i1'),
    expect: () => [
      const InvoiceDetailState(status: InvoiceDetailStatus.loading),
      const InvoiceDetailState(
        status: InvoiceDetailStatus.failure,
        failure: NetworkFailure('network_error'),
      ),
    ],
  );

  blocTest<InvoiceDetailCubit, InvoiceDetailState>(
    'reload does nothing before the first load',
    build: () => InvoiceDetailCubit(getTransactions),
    act: (cubit) => cubit.reload(),
    expect: () => <InvoiceDetailState>[],
    verify: (_) => verifyNever(() => getTransactions(any())),
  );
}