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
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
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
    usedCents: 43335,
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

  InvoiceEntity invoice({int paid = 0, InvoiceStatus status = InvoiceStatus.closed}) {
    return InvoiceEntity(
      id: 'i1',
      accountId: 'card1',
      referenceMonth: DateTime(2026, 3),
      periodStart: DateTime(2026, 2, 11),
      periodEnd: DateTime(2026, 3, 10),
      dueDate: DateTime(2026, 3, 17),
      status: status,
      totalCents: 43335,
      paidCents: paid,
    );
  }

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(
      PayInvoiceParams(invoiceId: 'x', fromAccountId: 'y', paidAt: DateTime(2026)),
    );
  });

  setUp(() {
    getTransactions = MockGetTransactions();
    getInvoices = MockGetInvoices();
    getAccounts = MockGetAccounts();
    payInvoice = MockPayInvoice();

    when(() => getTransactions('i1')).thenAnswer(
      (_) async => const Right<Failure, List<TransactionEntity>>([]),
    );
    when(() => getInvoices('card1')).thenAnswer(
      (_) async => Right<Failure, List<InvoiceEntity>>([invoice()]),
    );
    when(() => getAccounts('w1')).thenAnswer(
      (_) async => const Right<Failure, List<AccountEntity>>([checking]),
    );
  });

  InvoiceDetailCubit buildCubit() => InvoiceDetailCubit(
        getTransactions: getTransactions,
        getInvoices: getInvoices,
        getAccounts: getAccounts,
        payInvoice: payInvoice,
      );

  test('paying a part sends the amount, and the invoice stays unpaid', () async {
    final cubit = buildCubit();
    await cubit.load(invoice(), card);
    when(() => payInvoice(any())).thenAnswer((_) async => const Right<Failure, String>('tr1'));
    when(() => getInvoices('card1')).thenAnswer(
      (_) async => Right<Failure, List<InvoiceEntity>>([invoice(paid: 10000)]),
    );

    await cubit.pay('a2', amountCents: 10000);

    final params = verify(() => payInvoice(captureAny())).captured.single as PayInvoiceParams;
    expect(params.invoiceId, 'i1');
    expect(params.fromAccountId, 'a2');
    expect(params.amountCents, 10000);
    expect(cubit.state.paying, isFalse);
    expect(cubit.state.actionFailure, isNull);
    expect(cubit.state.invoice?.isPaid, isFalse);
    expect(cubit.state.invoice?.paidCents, 10000);
    expect(cubit.state.invoice?.remainingCents, 33335);
    expect(cubit.state.invoice?.isPartiallyPaid, isTrue);
    await cubit.close();
  });

  test('paying everything sends no amount', () async {
    final cubit = buildCubit();
    await cubit.load(invoice(), card);
    when(() => payInvoice(any())).thenAnswer((_) async => const Right<Failure, String>('tr1'));

    await cubit.pay('a2');

    final params = verify(() => payInvoice(captureAny())).captured.single as PayInvoiceParams;
    expect(params.amountCents, isNull);
    await cubit.close();
  });

  test('the invoice is loaded again after a part is paid, so the screen shows what is left', () async {
    final cubit = buildCubit();
    await cubit.load(invoice(), card);
    when(() => payInvoice(any())).thenAnswer((_) async => const Right<Failure, String>('tr1'));

    await cubit.pay('a2', amountCents: 5000);

    // Once to open the screen, once after the payment.
    verify(() => getInvoices('card1')).called(2);
    await cubit.close();
  });

  test('a second payment on top of the first adds to what was paid', () async {
    final cubit = buildCubit();
    await cubit.load(invoice(paid: 10000), card);
    when(() => payInvoice(any())).thenAnswer((_) async => const Right<Failure, String>('tr2'));
    when(() => getInvoices('card1')).thenAnswer(
      (_) async => Right<Failure, List<InvoiceEntity>>([invoice(paid: 25000)]),
    );

    await cubit.pay('a2', amountCents: 15000);

    expect(cubit.state.invoice?.paidCents, 25000);
    expect(cubit.state.invoice?.remainingCents, 18335);
    await cubit.close();
  });

  test('an amount above what is owed is reported, and nothing changes', () async {
    final cubit = buildCubit();
    await cubit.load(invoice(), card);
    when(() => payInvoice(any())).thenAnswer(
      (_) async => const Left<Failure, String>(RuleFailure('payment amount is above what is owed')),
    );

    await cubit.pay('a2', amountCents: 999999);

    expect(cubit.state.paying, isFalse);
    expect(cubit.state.actionFailure, const RuleFailure('payment amount is above what is owed'));
    expect(cubit.state.invoice?.paidCents, 0);
    await cubit.close();
  });

  test('the last part settles the invoice', () async {
    final cubit = buildCubit();
    await cubit.load(invoice(paid: 10000), card);
    when(() => payInvoice(any())).thenAnswer((_) async => const Right<Failure, String>('tr3'));
    when(() => getInvoices('card1')).thenAnswer(
      (_) async => Right<Failure, List<InvoiceEntity>>(
        [invoice(paid: 43335, status: InvoiceStatus.paid)],
      ),
    );

    await cubit.pay('a2');

    expect(cubit.state.invoice?.isPaid, isTrue);
    expect(cubit.state.invoice?.remainingCents, 0);
    await cubit.close();
  });

  test('a payment started while another is going on is ignored', () async {
    final cubit = buildCubit();
    await cubit.load(invoice(), card);
    when(() => payInvoice(any())).thenAnswer((_) async => const Right<Failure, String>('tr1'));

    final first = cubit.pay('a2', amountCents: 100);
    await cubit.pay('a2', amountCents: 200);
    await first;

    verify(() => payInvoice(any())).called(1);
    await cubit.close();
  });
}
