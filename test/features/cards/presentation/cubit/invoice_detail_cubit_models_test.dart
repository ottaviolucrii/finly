import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/data/models/account_model.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/cards/data/models/invoice_model.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_status.dart';
import 'package:finly/features/cards/domain/usecases/get_invoice_transactions_use_case.dart';
import 'package:finly/features/cards/domain/usecases/get_invoices_use_case.dart';
import 'package:finly/features/cards/domain/usecases/pay_invoice_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/invoice_detail_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/invoice_detail_state.dart';
import 'package:finly/features/transactions/data/models/transaction_model.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetTransactions extends Mock implements GetInvoiceTransactionsUseCase {}

class MockGetInvoices extends Mock implements GetInvoicesUseCase {}

class MockGetAccounts extends Mock implements GetAccountsUseCase {}

class MockPayInvoice extends Mock implements PayInvoiceUseCase {}

/// Regression test: the real data layer returns lists of *models*, not lists
/// of the base entities that the other cubit tests use.
void main() {
  test('load works with the model types the data layer returns', () async {
    final getTransactions = MockGetTransactions();
    final getInvoices = MockGetInvoices();
    final getAccounts = MockGetAccounts();

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
    final given = InvoiceEntity(
      id: 'i1',
      accountId: 'card1',
      referenceMonth: DateTime(2026, 3),
      periodStart: DateTime(2026, 2, 11),
      periodEnd: DateTime(2026, 3, 10),
      dueDate: DateTime(2026, 3, 17),
      status: InvoiceStatus.open,
      totalCents: 10000,
    );
    final refreshed = InvoiceModel(
      id: 'i1',
      accountId: 'card1',
      referenceMonth: DateTime(2026, 3),
      periodStart: DateTime(2026, 2, 11),
      periodEnd: DateTime(2026, 3, 10),
      dueDate: DateTime(2026, 3, 17),
      status: InvoiceStatus.paid,
      totalCents: 10000,
    );
    const checking = AccountModel(
      id: 'a2',
      workspaceId: 'w1',
      name: 'Conta corrente',
      type: AccountType.checking,
      currency: 'BRL',
      openingBalanceCents: 500000,
      postedBalanceCents: 500000,
      projectedBalanceCents: 500000,
    );

    when(() => getTransactions('i1')).thenAnswer(
      (_) async => Right<Failure, List<TransactionEntity>>(<TransactionModel>[]),
    );
    when(() => getInvoices('card1')).thenAnswer(
      (_) async => Right<Failure, List<InvoiceEntity>>(<InvoiceModel>[refreshed]),
    );
    when(() => getAccounts('w1')).thenAnswer(
      (_) async =>
          Right<Failure, List<AccountEntity>>(<AccountModel>[checking]),
    );

    final cubit = InvoiceDetailCubit(
      getTransactions: getTransactions,
      getInvoices: getInvoices,
      getAccounts: getAccounts,
      payInvoice: MockPayInvoice(),
    );
    await cubit.load(given, card);

    expect(cubit.state.status, InvoiceDetailStatus.loaded);
    expect(cubit.state.invoice?.isPaid, isTrue);
    expect(cubit.state.accounts, hasLength(1));
    await cubit.close();
  });
}