import 'package:finly/features/reminders/data/models/notification_prefs_model.dart';
import 'package:finly/features/reminders/data/models/reminder_bill_model.dart';
import 'package:finly/features/reminders/data/models/reminder_invoice_model.dart';
import 'package:finly/features/reminders/domain/entities/notification_prefs.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class RemindersRemoteDataSource {
  Future<NotificationPrefsModel> getPrefs();

  Future<void> savePrefs(NotificationPrefs prefs);

  Future<List<ReminderBillModel>> getBills(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  });

  Future<List<ReminderInvoiceModel>> getInvoices(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  });
}

class RemindersRemoteDataSourceImpl implements RemindersRemoteDataSource {
  final SupabaseClient _client;

  const RemindersRemoteDataSourceImpl(this._client);

  String _userId() {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AuthException('not_authenticated');
    return id;
  }

  /// "2026-10-01": how the database names a day.
  static String _date(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$month-$day';
  }

  @override
  Future<NotificationPrefsModel> getPrefs() async {
    // Row Level Security: a user reads and changes only their own row.
    final row = await _client
        .from('user_settings')
        .select('notification_prefs')
        .eq('user_id', _userId())
        .single();

    final prefs = row['notification_prefs'];
    return NotificationPrefsModel.fromMap(
      prefs is Map ? Map<String, dynamic>.from(prefs) : <String, dynamic>{},
    );
  }

  @override
  Future<void> savePrefs(NotificationPrefs prefs) async {
    await _client
        .from('user_settings')
        .update({'notification_prefs': prefs.toMap()})
        .eq('user_id', _userId());
  }

  @override
  Future<List<ReminderBillModel>> getBills(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) async {
    // Pending expenses that are not card purchases and not transfers: a card
    // purchase is paid by the invoice, which has its own reminder. The embed
    // brings the "lead days" of the recurring item the bill came from.
    final rows = await _client
        .from('transactions')
        .select('id, description, amount_cents, currency, occurred_at, recurring_transactions(lead_days)')
        .eq('workspace_id', workspaceId)
        .eq('status', 'pending')
        .eq('type', 'expense')
        .filter('deleted_at', 'is', 'null')
        .filter('invoice_id', 'is', 'null')
        .filter('transfer_id', 'is', 'null')
        .gte('occurred_at', from.toUtc().toIso8601String())
        .lt('occurred_at', to.toUtc().toIso8601String())
        .order('occurred_at')
        .limit(100);

    return rows.map(ReminderBillModel.fromMap).toList();
  }

  @override
  Future<List<ReminderInvoiceModel>> getInvoices(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) async {
    // The invoices have no workspace of their own: they belong to a card.
    final cards = await _client
        .from('accounts')
        .select('id, name, currency')
        .eq('workspace_id', workspaceId)
        .eq('type', 'credit_card');
    if (cards.isEmpty) return const [];

    final cardById = {for (final card in cards) card['id'] as String: card};

    final invoices = await _client
        .from('credit_card_invoices')
        .select('id, account_id, due_date')
        .filter('account_id', 'in', '(${cardById.keys.join(',')})')
        .neq('status', 'paid')
        .gte('due_date', _date(from))
        .lt('due_date', _date(to))
        .order('due_date');
    if (invoices.isEmpty) return const [];

    // What is still owed: the total minus the payments already made.
    final remaining = await _client
        .from('invoice_balances')
        .select('invoice_id, remaining_cents')
        .filter(
          'invoice_id',
          'in',
          '(${invoices.map((invoice) => invoice['id'] as String).join(',')})',
        );
    final totalById = {
      for (final row in remaining)
        row['invoice_id'] as String: (row['remaining_cents'] as num).toInt(),
    };

    return [
      for (final invoice in invoices)
        ReminderInvoiceModel.fromParts(
          invoice: invoice,
          card: cardById[invoice['account_id'] as String]!,
          totalCents: totalById[invoice['id'] as String] ?? 0,
        ),
    ];
  }
}
