import 'package:finly/features/categories/data/models/category_model.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/import/domain/statement_line.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// What the database says about the lines of a statement.
class ImportCheck {
  /// Per line: 'new', 'duplicate' or 'paid_invoice'.
  final List<String> statuses;
  final int newCount;
  final int duplicates;
  final int paidInvoice;

  const ImportCheck({
    required this.statuses,
    required this.newCount,
    required this.duplicates,
    required this.paidInvoice,
  });

  factory ImportCheck.fromJson(Map<String, dynamic> json) => ImportCheck(
        statuses: [for (final s in (json['rows'] as List? ?? const [])) '$s'],
        newCount: (json['new'] as num?)?.toInt() ?? 0,
        duplicates: (json['duplicates'] as num?)?.toInt() ?? 0,
        paidInvoice: (json['paid_invoice'] as num?)?.toInt() ?? 0,
      );
}

/// Everything the import screen asks the database.
abstract class ImportSource {
  Future<List<CategoryEntity>> categories(String workspaceId);

  /// The usual category for each description, from the person's history.
  Future<Map<String, String>> suggestions(String workspaceId, List<String> descriptions, {required bool income});

  /// Checks the lines ([save] false) or saves them all at once.
  Future<ImportCheck> run(String accountId, List<StatementLine> lines, List<String?> categoryIds, {required bool save});
}

class SupabaseImportSource implements ImportSource {
  final SupabaseClient _client;

  const SupabaseImportSource(this._client);

  @override
  Future<List<CategoryEntity>> categories(String workspaceId) async {
    final rows = await _client
        .from('categories')
        .select()
        .eq('workspace_id', workspaceId)
        .filter('archived_at', 'is', 'null')
        .order('name');
    return [for (final row in rows) CategoryModel.fromMap(row)];
  }

  @override
  Future<Map<String, String>> suggestions(String workspaceId, List<String> descriptions, {required bool income}) async {
    if (descriptions.isEmpty) return const {};
    final rows = await _client.rpc('suggest_categories', params: {
      'p_workspace': workspaceId,
      'p_descriptions': descriptions,
      'p_type': income ? 'income' : 'expense',
    });
    return {
      for (final row in (rows as List))
        if (row['category_id'] != null) '${row['description']}': '${row['category_id']}',
    };
  }

  @override
  Future<ImportCheck> run(String accountId, List<StatementLine> lines, List<String?> categoryIds, {required bool save}) async {
    String day(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final result = await _client.rpc('import_transactions', params: {
      'p_account': accountId,
      'p_dry_run': !save,
      'p_rows': [
        for (var i = 0; i < lines.length; i++)
          {
            'date': day(lines[i].date),
            'amount_cents': lines[i].amountCents,
            'description': lines[i].description,
            if (lines[i].externalId != null) 'external_id': lines[i].externalId,
            if (categoryIds[i] != null) 'category_id': categoryIds[i],
          },
      ],
    });
    return ImportCheck.fromJson(Map<String, dynamic>.from(result as Map));
  }
}
