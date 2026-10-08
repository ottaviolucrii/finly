import 'package:equatable/equatable.dart';

/// What happened to a row, as the database writes it (INSERT, UPDATE, DELETE).
enum AuditAction {
  insert,
  update,
  delete;

  /// Reads the label of the database enum. Throws for an unknown one, so a new
  /// action is noticed.
  static AuditAction fromDb(String value) => values.byName(value.toLowerCase());
}

/// One line of the audit log: a row that was created, changed or removed. The
/// database keeps the whole row before and after (jsonb).
class AuditRecord extends Equatable {
  final String id;
  final String tableName;
  final String recordId;
  final AuditAction action;

  /// The row before the change (null for an INSERT).
  final Map<String, dynamic>? oldData;

  /// The row after the change (null for a DELETE).
  final Map<String, dynamic>? newData;

  /// When it happened, in UTC as the database gives it.
  final DateTime occurredAt;

  const AuditRecord({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.action,
    required this.occurredAt,
    this.oldData,
    this.newData,
  });

  @override
  List<Object?> get props => [id, tableName, recordId, action, oldData, newData, occurredAt];
}

/// The names behind the ids that appear in the log (an account or a category
/// of the workspace), so "account_id changed" can say which account.
class AuditLookup extends Equatable {
  final Map<String, String> accountNames;
  final Map<String, String> categoryNames;

  const AuditLookup({
    this.accountNames = const {},
    this.categoryNames = const {},
  });

  @override
  List<Object?> get props => [accountNames, categoryNames];
}
