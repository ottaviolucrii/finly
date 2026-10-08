import 'package:finly/features/data_export/domain/entities/user_data_snapshot.dart';

/// The version of the layout of the file. It changes when the layout does, so
/// whoever reads the file knows what to expect.
const int exportFormatVersion = 1;

/// "finly-meus-dados-2026-10-07.json".
String exportFileName(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return 'finly-meus-dados-${date.year}-$month-$day.json';
}

/// Rows grouped by the text found under [key]. Rows with no such value are
/// left out.
Map<String, List<JsonRow>> _groupBy(List<JsonRow> rows, String key) {
  final groups = <String, List<JsonRow>>{};
  for (final row in rows) {
    final value = row[key];
    if (value is! String) continue;
    groups.putIfAbsent(value, () => []).add(row);
  }
  return groups;
}

int _byOccurredAt(JsonRow a, JsonRow b) {
  final left = (a['occurred_at'] ?? '').toString();
  final right = (b['occurred_at'] ?? '').toString();
  final byDate = left.compareTo(right);
  return byDate != 0 ? byDate : (a['id'] ?? '').toString().compareTo((b['id'] ?? '').toString());
}

/// The document that goes into the file: who the user is, their settings and,
/// for each workspace, everything that belongs to it. Amounts stay in cents,
/// as the database has them. Credit card details and invoices belong to an
/// account, so they are put under the workspace of that account.
Map<String, dynamic> buildExportDocument(UserDataSnapshot data, DateTime exportedAt) {
  final accountsByWorkspace = _groupBy(data.accounts, 'workspace_id');
  final categoriesByWorkspace = _groupBy(data.categories, 'workspace_id');
  final budgetsByWorkspace = _groupBy(data.budgets, 'workspace_id');
  final recurringByWorkspace = _groupBy(data.recurring, 'workspace_id');
  final transactionsByWorkspace = _groupBy(data.transactions, 'workspace_id');

  final workspaceOfAccount = <String, String>{
    for (final account in data.accounts)
      if (account['id'] is String && account['workspace_id'] is String)
        account['id'] as String: account['workspace_id'] as String,
  };

  List<JsonRow> belongingToAccountsOf(String workspaceId, List<JsonRow> rows) {
    return [
      for (final row in rows)
        if (workspaceOfAccount[row['account_id']] == workspaceId) row,
    ];
  }

  return {
    'app': 'Finly',
    'format_version': exportFormatVersion,
    'exported_at': exportedAt.toUtc().toIso8601String(),
    'notes': [
      'Todos os valores em dinheiro estão em centavos (inteiros): 1500 = 15,00.',
      'Datas e horas em UTC (ISO 8601).',
      'As transações com deleted_at preenchido estão na lixeira (somem depois de 30 dias).',
      'Os comprovantes anexados não estão neste arquivo.',
    ],
    'account': {
      'id': data.userId,
      'email': data.email,
      'full_name': data.profile?['full_name'],
      'created_at': data.profile?['created_at'],
    },
    'profile': data.profile,
    'settings': data.settings,
    'workspaces': [
      for (final workspace in data.workspaces)
        {
          ...workspace,
          'accounts': accountsByWorkspace[workspace['id']] ?? const <JsonRow>[],
          'credit_cards': belongingToAccountsOf(workspace['id'] as String? ?? '', data.cardDetails),
          'credit_card_invoices': belongingToAccountsOf(workspace['id'] as String? ?? '', data.invoices),
          'categories': categoriesByWorkspace[workspace['id']] ?? const <JsonRow>[],
          'budgets': budgetsByWorkspace[workspace['id']] ?? const <JsonRow>[],
          'recurring_transactions': recurringByWorkspace[workspace['id']] ?? const <JsonRow>[],
          'transactions': [...?transactionsByWorkspace[workspace['id']]]..sort(_byOccurredAt),
        },
    ],
    'transfers': data.transfers,
    'truncated_tables': data.truncatedTables.toList()..sort(),
  };
}
