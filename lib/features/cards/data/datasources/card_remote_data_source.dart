import 'package:finly/features/cards/data/models/credit_card_model.dart';
import 'package:finly/features/cards/data/models/invoice_model.dart';
import 'package:finly/features/transactions/data/models/transaction_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class CardRemoteDataSource {
  Future<List<CreditCardModel>> getCards(String workspaceId);

  Future<String> createCard({
    required String workspaceId,
    required String name,
    required String currency,
    required int limitCents,
    required int closingDay,
    required int dueDay,
  });

  Future<void> updateCard({
    required String accountId,
    required String name,
    required int limitCents,
    required int closingDay,
    required int dueDay,
  });

  Future<List<InvoiceModel>> getInvoices(String accountId);

  Future<List<TransactionModel>> getInvoiceTransactions(String invoiceId);

  Future<String> createInstallments({
    required String accountId,
    String? categoryId,
    required int totalCents,
    required int installments,
    required String description,
    required DateTime purchaseAt,
  });

  /// Pays [amountCents] of the invoice, or everything still owed when null.
  Future<String> payInvoice({
    required String invoiceId,
    required String fromAccountId,
    required DateTime paidAt,
    int? amountCents,
  });
}

class CardRemoteDataSourceImpl implements CardRemoteDataSource {
  final SupabaseClient _client;

  const CardRemoteDataSourceImpl(this._client);

  @override
  Future<List<CreditCardModel>> getCards(String workspaceId) async {
    final accounts = await _client
        .from('accounts')
        .select()
        .eq('workspace_id', workspaceId)
        .eq('type', 'credit_card')
        .filter('archived_at', 'is', 'null')
        .order('created_at');

    // Row Level Security limits the settings to the user's own cards; they
    // are matched to the accounts of this workspace by id.
    final details = await _client.from('credit_card_details').select();

    // Balances are derived by the database view, never stored.
    final balances = await _client
        .from('account_balances')
        .select()
        .eq('workspace_id', workspaceId);

    final detailsById = {
      for (final row in details) row['account_id'] as String: row,
    };
    final balanceById = {
      for (final row in balances) row['account_id'] as String: row,
    };

    final cards = <CreditCardModel>[];
    for (final account in accounts) {
      final id = account['id'] as String;
      final cardDetails = detailsById[id];
      if (cardDetails == null) continue; // not a configured card
      cards.add(
        CreditCardModel.fromMaps(
          account: account,
          details: cardDetails,
          balance: balanceById[id],
        ),
      );
    }
    return cards;
  }

  @override
  Future<String> createCard({
    required String workspaceId,
    required String name,
    required String currency,
    required int limitCents,
    required int closingDay,
    required int dueDay,
  }) async {
    // Database function (sql/08_credit_card.sql): creates the account and its
    // settings in one operation.
    final id = await _client.rpc(
      'create_credit_card',
      params: {
        'p_workspace_id': workspaceId,
        'p_name': name,
        'p_currency': currency,
        'p_limit_cents': limitCents,
        'p_closing_day': closingDay,
        'p_due_day': dueDay,
      },
    );
    return id as String;
  }

  @override
  Future<void> updateCard({
    required String accountId,
    required String name,
    required int limitCents,
    required int closingDay,
    required int dueDay,
  }) async {
    // The name goes first: it is the only part that can clash with another
    // account (a unique index). The settings are range-checked by the app
    // and by the database, so they are unlikely to fail after it.
    await _client.from('accounts').update({'name': name}).eq('id', accountId);

    await _client
        .from('credit_card_details')
        .update({
          'limit_cents': limitCents,
          'closing_day': closingDay,
          'due_day': dueDay,
        })
        .eq('account_id', accountId);
  }

  @override
  Future<List<InvoiceModel>> getInvoices(String accountId) async {
    final invoices = await _client
        .from('credit_card_invoices')
        .select()
        .eq('account_id', accountId)
        .order('reference_month', ascending: false);

    // Total and paid per invoice, derived by the database (an invoice with no
    // purchases and no payments has zero of both).
    final balances = await _client
        .from('invoice_balances')
        .select()
        .eq('account_id', accountId);

    final balanceById = {
      for (final row in balances) row['invoice_id'] as String: row,
    };

    return invoices.map((row) {
      final balance = balanceById[row['id'] as String];
      return InvoiceModel.fromMap(
        row,
        totalCents: (balance?['total_cents'] as num?)?.toInt() ?? 0,
        paidCents: (balance?['paid_cents'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  @override
  Future<List<TransactionModel>> getInvoiceTransactions(
    String invoiceId,
  ) async {
    final rows = await _client
        .from('transactions')
        .select()
        .eq('invoice_id', invoiceId)
        .filter('deleted_at', 'is', 'null')
        .order('occurred_at', ascending: false);

    return rows.map(TransactionModel.fromMap).toList();
  }

  @override
  Future<String> createInstallments({
    required String accountId,
    String? categoryId,
    required int totalCents,
    required int installments,
    required String description,
    required DateTime purchaseAt,
  }) async {
    // Database function (sql/03_logic.sql): one charge per part, on
    // consecutive invoices; the first part absorbs the rounding remainder.
    final group = await _client.rpc(
      'create_installments',
      params: {
        'p_account_id': accountId,
        'p_category_id': categoryId,
        'p_total_cents': totalCents,
        'p_installments': installments,
        'p_description': description,
        'p_purchase_at': purchaseAt.toUtc().toIso8601String(),
      },
    );
    return group as String;
  }

  @override
  Future<String> payInvoice({
    required String invoiceId,
    required String fromAccountId,
    required DateTime paidAt,
    int? amountCents,
  }) async {
    // Database function (sql/18_invoice_partial_payment.sql): creates the
    // payment transfer; the invoice is marked paid only when nothing is owed.
    // Without an amount it pays everything that is still owed.
    final transfer = await _client.rpc(
      'pay_invoice',
      params: {
        'p_invoice_id': invoiceId,
        'p_from_account_id': fromAccountId,
        'p_paid_at': paidAt.toUtc().toIso8601String(),
        if (amountCents != null) 'p_amount_cents': amountCents,
      },
    );
    return transfer as String;
  }
}