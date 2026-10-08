import 'package:equatable/equatable.dart';

/// What happened, in the words of the screen.
enum AuditKind { created, edited, deleted, trashed, restored }

/// One field that changed: its name for a person and the values before and
/// after, already written as text.
class AuditChange extends Equatable {
  final String label;
  final String before;
  final String after;

  const AuditChange({required this.label, required this.before, required this.after});

  @override
  List<Object?> get props => [label, before, after];
}

/// A line of the history, ready to show.
class AuditItem extends Equatable {
  final String id;
  final String tableName;
  final AuditKind kind;

  /// "Saída criada: Mercado".
  final String title;

  /// "Saída · R$ 120,00 · 07/10/2026" (may be empty).
  final String summary;

  /// The fields that changed (only for an edit).
  final List<AuditChange> changes;

  /// When it happened, on the phone's clock.
  final DateTime occurredAt;

  const AuditItem({
    required this.id,
    required this.tableName,
    required this.kind,
    required this.title,
    required this.summary,
    required this.changes,
    required this.occurredAt,
  });

  @override
  List<Object?> get props => [id, tableName, kind, title, summary, changes, occurredAt];
}

/// A page of the history.
class AuditPage extends Equatable {
  final List<AuditItem> items;

  /// True when the page was full, so there may be more to read.
  final bool hasMore;

  const AuditPage({required this.items, required this.hasMore});

  @override
  List<Object?> get props => [items, hasMore];
}
