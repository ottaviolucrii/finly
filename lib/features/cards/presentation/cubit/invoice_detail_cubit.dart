import 'package:finly/core/error/failure.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/usecases/get_invoice_transactions_use_case.dart';
import 'package:finly/features/cards/domain/usecases/get_invoices_use_case.dart';
import 'package:finly/features/cards/domain/usecases/pay_invoice_use_case.dart';
import 'package:finly/features/cards/presentation/cubit/invoice_detail_state.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The contents of one invoice, and paying it.
class InvoiceDetailCubit extends Cubit<InvoiceDetailState> {
  final GetInvoiceTransactionsUseCase _getTransactions;
  final GetInvoicesUseCase _getInvoices;
  final GetAccountsUseCase _getAccounts;
  final PayInvoiceUseCase _payInvoice;
  InvoiceEntity? _invoice;
  CreditCardEntity? _card;

  InvoiceDetailCubit({
    required GetInvoiceTransactionsUseCase getTransactions,
    required GetInvoicesUseCase getInvoices,
    required GetAccountsUseCase getAccounts,
    required PayInvoiceUseCase payInvoice,
  })  : _getTransactions = getTransactions,
        _getInvoices = getInvoices,
        _getAccounts = getAccounts,
        _payInvoice = payInvoice,
        super(const InvoiceDetailState());

  Future<void> load(InvoiceEntity invoice, CreditCardEntity card) async {
    _invoice = invoice;
    _card = card;
    // Keep the old data on screen while reloading, to avoid flicker.
    emit(InvoiceDetailState(
      status: InvoiceDetailStatus.loading,
      invoice: state.invoice ?? invoice,
      transactions: state.transactions,
      accounts: state.accounts,
    ));

    final transactions = await _getTransactions(invoice.id);
    final invoices = await _getInvoices(card.accountId);
    final accounts = await _getAccounts(card.workspaceId);

    Failure? failure;
    var transactionList = const <TransactionEntity>[];
    var invoiceList = const <InvoiceEntity>[];
    var accountList = const <AccountEntity>[];

    transactions.fold((f) {
      failure ??= f;
    }, (value) {
      transactionList = value;
    });
    invoices.fold((f) {
      failure ??= f;
    }, (value) {
      invoiceList = value;
    });
    accounts.fold((f) {
      failure ??= f;
    }, (value) {
      accountList = value;
    });

    final loadFailure = failure;
    if (loadFailure != null) {
      emit(InvoiceDetailState(
        status: InvoiceDetailStatus.failure,
        invoice: state.invoice ?? invoice,
        failure: loadFailure,
      ));
      return;
    }

    // A plain loop, not firstWhere(orElse: ...): the list that comes back
    // holds data-layer models, and an orElse that returns the base type
    // would throw a TypeError at runtime.
    var fresh = invoice;
    for (final candidate in invoiceList) {
      if (candidate.id == invoice.id) {
        fresh = candidate;
        break;
      }
    }

    final sources = accountList
        .where(
          (account) =>
              account.type != AccountType.creditCard &&
              account.currency == card.currency,
        )
        .toList();

    emit(InvoiceDetailState(
      status: InvoiceDetailStatus.loaded,
      invoice: fresh,
      transactions: transactionList,
      accounts: sources,
    ));
  }

  Future<void> reload() async {
    final invoice = _invoice;
    final card = _card;
    if (invoice != null && card != null) await load(invoice, card);
  }

  /// Pays [amountCents] of the invoice from [fromAccountId] (everything still
  /// owed when it is null), then reloads it.
  Future<void> pay(String fromAccountId, {int? amountCents}) async {
    final invoice = state.invoice ?? _invoice;
    if (invoice == null || state.paying) return;

    emit(state.withChanges(paying: true));
    final result = await _payInvoice(
      PayInvoiceParams(
        invoiceId: invoice.id,
        fromAccountId: fromAccountId,
        paidAt: DateTime.now(),
        amountCents: amountCents,
      ),
    );

    await result.fold<Future<void>>(
      (failure) async =>
          emit(state.withChanges(paying: false, actionFailure: failure)),
      (_) async {
        emit(state.withChanges(paying: false));
        await reload();
      },
    );
  }
}