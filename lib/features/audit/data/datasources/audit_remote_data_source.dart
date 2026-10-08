import 'package:finly/features/audit/domain/audit_filter.dart';
import 'package:finly/features/audit/domain/entities/audit_record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One row of `audit_logs` as an [AuditRecord]. Throws when a column is not
/// what it should be, so the repository can turn it into a failure.
AuditRecord auditRecordFromRow(Map<String, dynamic> row) {
  Map<String, dynamic>? data(String key) {
    final value = row[key];
    return value == null ? null : Map<String, dynamic>.from(value as Map);
  }

  // The id of a line of the log is a number (bigint); a record id is a uuid.
  // Both are kept as text, whichever the database gives.
  String text(String key) {
    final value = row[key];
    if (value == null) throw FormatException('Missing $key in the audit log');
    return value.toString();
  }

  return AuditRecord(
    id: text('id'),
    tableName: row['table_name'] as String,
    recordId: text('record_id'),
    action: AuditAction.fromDb(row['action'] as String),
    oldData: data('old_data'),
    newData: data('new_data'),
    occurredAt: DateTime.parse(row['occurred_at'] as String),
  );
}

/// Talks to Supabase. Throws Supabase exceptions; the repository maps them.
abstract class AuditRemoteDataSource {
  Future<List<AuditRecord>> getRecords(
    String workspaceId, {
    required int offset,
    required int limit,
    AuditFilter filter = AuditFilter.all,
  });

  Future<AuditLookup> getLookup(String workspaceId);
}

class AuditRemoteDataSourceImpl implements AuditRemoteDataSource {
  final SupabaseClient _client;

  const AuditRemoteDataSourceImpl(this._client);

  @override
  Future<List<AuditRecord>> getRecords(
    String workspaceId, {
    required int offset,
    required int limit,
    AuditFilter filter = AuditFilter.all,
  }) async {
    // Row Level Security: only the rows of this user's workspaces come back.
    var query = _client.from('audit_logs').select().eq('workspace_id', workspaceId);
    if (filter.tables.isNotEmpty) {
      query = query.filter('table_name', 'in', '(${filter.tables.join(',')})');
    }

    final rows = await query
        .order('occurred_at', ascending: false)
        .order('id')
        .range(offset, offset + limit - 1);

    return [for (final row in rows) auditRecordFromRow(row)];
  }

  @override
  Future<AuditLookup> getLookup(String workspaceId) async {
    final accounts = await _client
        .from('accounts')
        .select('id, name')
        .eq('workspace_id', workspaceId);
    final categories = await _client
        .from('categories')
        .select('id, name')
        .eq('workspace_id', workspaceId);

    return AuditLookup(
      accountNames: {
        for (final row in accounts) row['id'] as String: row['name'] as String,
      },
      categoryNames: {
        for (final row in categories) row['id'] as String: row['name'] as String,
      },
    );
  }
}
