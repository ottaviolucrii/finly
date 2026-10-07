import 'package:finly/core/utils/iso_date.dart';
import 'package:finly/features/forecast/domain/entities/forecast_items.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class ForecastRemoteDataSource {
  Future<ForecastInputs> getInputs(String workspaceId, {required DateTime until});
}

class ForecastRemoteDataSourceImpl implements ForecastRemoteDataSource {
  final SupabaseClient _client;

  const ForecastRemoteDataSourceImpl(this._client);

  /// A timestamp of the database as the day it is on the phone.
  static DateTime _localDay(String timestamp) {
    final local = DateTime.parse(timestamp).toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  @override
  Future<ForecastInputs> getInputs(
    String workspaceId, {
    required DateTime until,
  }) async {
    // The accounts first: they tell which ones are cards and which are archived.
    final accounts = await _client
        .from('accounts')
        .select('id, name, type, currency, archived_at')
        .eq('workspace_id', workspaceId);

    final cardById = <String, Map<String, dynamic>>{};
    final archivedIds = <String>{};
    for (final account in accounts) {
      final id = account['id'] as String;
      if (account['type'] == 'credit_card') cardById[id] = account;
      if (account['archived_at'] != null) archivedIds.add(id);
    }

    return ForecastInputs(
      startingBalances: await _startingBalances(workspaceId, archivedIds),
      pending: await _pending(workspaceId, until),
      recurring: await _recurring(workspaceId, cardById.keys.toSet()),
      invoices: await _invoices(cardById, until),
    );
  }

  /// What the accounts hold now (confirmed movements only), per currency.
  /// Credit cards and archived accounts are left out.
  Future<Map<String, int>> _startingBalances(
    String workspaceId,
    Set<String> archivedIds,
  ) async {
    final rows = await _client
        .from('account_balances')
        .select('account_id, currency, posted_balance_cents')
        .eq('workspace_id', workspaceId)
        .neq('type', 'credit_card');

    final totals = <String, int>{};
    for (final row in rows) {
      if (archivedIds.contains(row['account_id'])) continue;
      final currency = row['currency'] as String;
      totals[currency] =
          (totals[currency] ?? 0) + (row['posted_balance_cents'] as num).toInt();
    }
    return totals;
  }

  /// Pending incomes and expenses that are not card purchases (those belong to
  /// an invoice) and not transfers.
  Future<List<PendingFlow>> _pending(String workspaceId, DateTime until) async {
    final rows = await _client
        .from('transactions')
        .select('id, description, amount_cents, currency, type, occurred_at')
        .eq('workspace_id', workspaceId)
        .eq('status', 'pending')
        .filter('type', 'in', '(income,expense)')
        .filter('deleted_at', 'is', 'null')
        .filter('invoice_id', 'is', 'null')
        .filter('transfer_id', 'is', 'null')
        .lt('occurred_at', until.toUtc().toIso8601String())
        .order('occurred_at')
        .limit(500);

    return [
      for (final row in rows)
        PendingFlow(
          id: row['id'] as String,
          description: row['description'] as String,
          amountCents: (row['amount_cents'] as num).toInt(),
          currency: row['currency'] as String,
          isIncome: row['type'] == 'income',
          date: _localDay(row['occurred_at'] as String),
        ),
    ];
  }

  /// Active recurring items, except the ones on a credit card (a purchase on a
  /// card is paid by the invoice, which is counted on its own).
  Future<List<RecurringTemplate>> _recurring(
    String workspaceId,
    Set<String> cardIds,
  ) async {
    final rows = await _client
        .from('recurring_transactions')
        .select('id, account_id, description, amount_cents, currency, type, '
            'frequency, interval_count, start_date, end_date, generated_count, created_at')
        .eq('workspace_id', workspaceId)
        .eq('is_active', true);

    return [
      for (final row in rows)
        if (!cardIds.contains(row['account_id']))
          RecurringTemplate(
            id: row['id'] as String,
            description: row['description'] as String,
            amountCents: (row['amount_cents'] as num).toInt(),
            currency: row['currency'] as String,
            isIncome: row['type'] == 'income',
            frequency: ForecastFrequency.fromDb(row['frequency'] as String),
            intervalCount: (row['interval_count'] as num).toInt(),
            startDate: parseIsoDate(row['start_date'] as String),
            endDate: row['end_date'] == null ? null : parseIsoDate(row['end_date'] as String),
            generatedCount: (row['generated_count'] as num).toInt(),
            createdOn: _localDay(row['created_at'] as String),
          ),
    ];
  }

  /// Unpaid invoices of the cards, with what they add up to now.
  Future<List<InvoiceDue>> _invoices(
    Map<String, Map<String, dynamic>> cardById,
    DateTime until,
  ) async {
    if (cardById.isEmpty) return const [];

    final invoices = await _client
        .from('credit_card_invoices')
        .select('id, account_id, due_date')
        .filter('account_id', 'in', '(${cardById.keys.join(',')})')
        .neq('status', 'paid')
        .lt('due_date', isoDate(until))
        .order('due_date');
    if (invoices.isEmpty) return const [];

    final totals = await _client
        .from('invoice_totals')
        .select('invoice_id, total_cents')
        .filter(
          'invoice_id',
          'in',
          '(${invoices.map((invoice) => invoice['id'] as String).join(',')})',
        );
    final totalById = {
      for (final row in totals)
        row['invoice_id'] as String: (row['total_cents'] as num).toInt(),
    };

    return [
      for (final invoice in invoices)
        InvoiceDue(
          id: invoice['id'] as String,
          cardName: cardById[invoice['account_id'] as String]!['name'] as String,
          totalCents: totalById[invoice['id'] as String] ?? 0,
          currency: cardById[invoice['account_id'] as String]!['currency'] as String,
          dueDate: parseIsoDate(invoice['due_date'] as String),
        ),
    ];
  }
}
