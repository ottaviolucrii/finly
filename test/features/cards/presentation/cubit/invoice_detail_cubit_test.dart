import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_status.dart';
import 'package:finly/features/cards/domain/usecases/get_invoice_transactions_use_case.dart';
import 'package:finly/features/cards/domain/usecases/get_invoices_use_case.dart';
import 'package:finly/features/cards/domain/usecases/pay_invoice_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/invoice_detail_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/invoice_detail_state.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetTransactions extends Mock implements GetInvoiceTransactionsUseCase {}

class MockGetInvoices extends Mock implements GetInvoicesUseCase {}

class MockGetAccounts extends Mock implements GetAccountsUseCase {}

class MockPayInvoice extends Mock implements PayInvoiceUseCase {}

void main() {
  late MockGetTransactions getTransactions;
  late MockGetInvoices getInvoices;
  late MockGetAccounts getAccounts;
  late MockPayInvoice payInvoice;

  const card = CreditCardEntity(
    accountId: 'card1',
    workspaceId: 'w1',
    name: 'Nubank',
    currency: 'BRL',
    limitCents: 500000,
    closingDay: 10,
    dueDay: 17,
    usedCents: 10000,
  );

  InvoiceEntity invoice(InvoiceStatus status) => InvoiceEntity(
        id: 'i1',
        accountId: 'card1',
        referenceMonth: DateTime(2026, 3),
        periodStart: DateTime(2026, 2, 11),
        periodEnd: DateTime(2026, 3, 10),
        dueDate: DateTime(2026, 3, 17),
        status: status,
        totalCents: 10000,
      );

  final purchase = TransactionEntity(
    id: 't1',
    workspaceId: 'w1',
    accountId: 'card1',
    categoryId: null,
    type: TransactionType.expense,
    status: TransactionStatus.posted,
    amountCents: 10000,
    currency: 'BRL',
    description: 'Notebook',
    occurredAt: DateTime(2026, 3, 5, 12),
  );

  const checking = AccountEntity(
    id: 'a2',
    workspaceId: 'w1',
    name: 'Conta corrente',
    type: AccountType.checking,
    currency: 'BRL',
    openingBalanceCents: 500000,
    postedBalanceCents: 500000,
    projectedBalanceCents: 500000,
  );
  const dollars = AccountEntity(
    id: 'a3',
    workspaceId: 'w1',
    name: 'Conta USD',
    type: AccountType.checking,
    currency: 'USD',
    openingBalanceCents: 100000,
    postedBalanceCents: 100000,
    projectedBalanceCents: 100000,
  );
  const cardAccount = AccountEntity(
    id: 'card1',
    workspaceId: 'w1',
    name: 'Nubank',
    type: AccountType.creditCard,
    currency: 'BRL',
    openingBalanceCents: 0,
    postedBalanceCents: -10000,
    projectedBalanceCents: -10000,
  );

  setUp(() {
    getTransactions = MockGetTransactions();
    getInvoices = MockGetInvoices();
    getAccounts = MockGetAccounts();
    payInvoice = MockPayInvoice();

    when(() => getTransactions('i1')).thenAnswer(
      (_) async => Right<Failure, List<TransactionEntity>>([purchase]),
    );
    when(() => getInvoices('card1')).thenAnswer(
      (_) async => Right<Failure, List<InvoiceEntity>>(
        [invoice(InvoiceStatus.closed)],
      ),
    );
    when(() => getAccounts('w1')).thenAnswer(
      (_) async => const Right<Failure, List<AccountEntity>>(
        [checking, dollars, cardAccount],
      ),
    );
  });

    setUpAll(() {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(
      PayInvoiceParams(
        invoiceId: 'x',
        fromAccountId: 'y',
        paidAt: DateTime(2026),
      ),
    );
  });

  InvoiceDetailCubit buildCubit() => InvoiceDetailCubit(
        getTransactions: getTransactions,
        getInvoices: getInvoices,
        getAccounts: getAccounts,
        payInvoice: payInvoice,
      );

  blocTest<InvoiceDetailCubit, InvoiceDetailState>(
    'load emits loading, then the fresh invoice, purchases and paying accounts',
    build: buildCubit,
    act: (cubit) => cubit.load(invoice(InvoiceStatus.open), card),
    expect: () => [
      InvoiceDetailState(
        status: InvoiceDetailStatus.loading,
        invoice: invoice(InvoiceStatus.open),
      ),
      // The invoice is refreshed from the server (now closed), and only the
      // BRL account that is not a card can pay it.
      InvoiceDetailState(
        status: InvoiceDetailStatus.loaded,
        invoice: invoice(InvoiceStatus.closed),
        transactions: [purchase],
        accounts: const [checking],
      ),
    ],
  );

  blocTest<InvoiceDetailCubit, InvoiceDetailState>(
    'load fails as a whole when any part fails',
    build: () {
      when(() => getTransactions('i1')).thenAnswer(
        (_) async => const Left<Failure, List<TransactionEntity>>(
          NetworkFailure('network_error'),
        ),
      );
      return buildCubit();
    },
    act: (cubit) => cubit.load(invoice(InvoiceStatus.open), card),
    expect: () => [
      InvoiceDetailState(
        status: InvoiceDetailStatus.loading,
        invoice: invoice(InvoiceStatus.open),
      ),
      InvoiceDetailState(
        status: InvoiceDetailStatus.failure,
        invoice: invoice(InvoiceStatus.open),
        failure: const NetworkFailure('network_error'),
      ),
    ],
  );

  blocTest<InvoiceDetailCubit, InvoiceDetailState>(
    'reload does nothing before the first load',
    build: buildCubit,
    act: (cubit) => cubit.reload(),
    expect: () => <InvoiceDetailState>[],
    verify: (_) => verifyNever(() => getTransactions(any())),
  );

  test('paying marks the invoice as paid and stops the progress', () async {
    final cubit = buildCubit();
    await cubit.load(invoice(InvoiceStatus.open), card);

    when(() => payInvoice(any()))
        .thenAnswer((_) async => const Right<Failure, String>('tr1'));
    // After payment the server reports the invoice as paid.
    when(() => getInvoices('card1')).thenAnswer(
      (_) async => Right<Failure, List<InvoiceEntity>>(
        [
          InvoiceEntity(
            id: 'i1',
            accountId: 'card1',
            referenceMonth: DateTime(2026, 3),
            periodStart: DateTime(2026, 2, 11),
            periodEnd: DateTime(2026, 3, 10),
            dueDate: DateTime(2026, 3, 17),
            status: InvoiceStatus.paid,
            totalCents: 10000,
          ),
        ],
      ),
    );

    await cubit.pay('a2');

    expect(cubit.state.paying, isFalse);
    expect(cubit.state.invoice?.isPaid, isTrue);
    expect(cubit.state.actionFailure, isNull);

    final captured =
        verify(() => payInvoice(captureAny())).captured.single as PayInvoiceParams;
    expect(captured.invoiceId, 'i1');
    expect(captured.fromAccountId, 'a2');
    await cubit.close();
  });

  test('a refused payment keeps the invoice and reports the reason', () async {
    final cubit = buildCubit();
    await cubit.load(invoice(InvoiceStatus.open), card);

    when(() => payInvoice(any())).thenAnswer(
      (_) async => const Left<Failure, String>(
        RuleFailure('invoice already paid'),
      ),
    );

    await cubit.pay('a2');

    expect(cubit.state.paying, isFalse);
    expect(cubit.state.invoice?.isPaid, isFalse);
    expect(
      cubit.state.actionFailure,
      const RuleFailure('invoice already paid'),
    );
    await cubit.close();
  });

  test('paying before the invoice is loaded does nothing', () async {
    final cubit = buildCubit();

    await cubit.pay('a2');

    verifyNever(() => payInvoice(any()));
    await cubit.close();
  });
}