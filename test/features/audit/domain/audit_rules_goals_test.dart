import 'package:finly/core/money/money.dart';
import 'package:finly/features/audit/domain/audit_rules.dart';
import 'package:finly/features/audit/domain/entities/audit_item.dart';
import 'package:finly/features/audit/domain/entities/audit_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const lookup = AuditLookup(accountNames: {'a1': 'Poupança', 'a2': 'Nubank'});

  String money(int cents) => Money(cents, 'BRL').format();

  Map<String, dynamic> goal({
    String name = 'Reserva',
    int target = 500000,
    String? date = '2027-06-30',
    String accountId = 'a1',
    String? archivedAt,
  }) {
    return {
      'id': 'g1',
      'name': name,
      'target_cents': target,
      'target_date': date,
      'account_id': accountId,
      'archived_at': archivedAt,
      'currency': 'BRL',
      'workspace_id': 'w1',
      'updated_at': '2026-10-07T12:00:00+00:00',
    };
  }

  AuditRecord record(AuditAction action, {Map<String, dynamic>? before, Map<String, dynamic>? after}) {
    return AuditRecord(
      id: '1',
      tableName: 'goals',
      recordId: 'g1',
      action: action,
      oldData: before,
      newData: after,
      occurredAt: DateTime.utc(2026, 10, 7, 12),
    );
  }

  test('a goal that was created', () {
    final item = describeAudit(record(AuditAction.insert, after: goal()), lookup);

    expect(item.kind, AuditKind.created);
    expect(item.title, 'Meta criada: Reserva');
    expect(item.summary, 'meta de ${money(500000)} · até 30/06/2027');
  });

  test('a goal with no date has no "até" in its summary', () {
    final item = describeAudit(record(AuditAction.insert, after: goal(date: null)), lookup);

    expect(item.summary, 'meta de ${money(500000)}');
  });

  test('a goal that was edited says what changed', () {
    final item = describeAudit(
      record(
        AuditAction.update,
        before: goal(target: 500000, date: '2027-06-30'),
        after: goal(target: 700000, date: null),
      ),
      lookup,
    );

    expect(item.title, 'Meta alterada: Reserva');
    expect(item.changes, [
      AuditChange(label: 'Valor da meta', before: money(500000), after: money(700000)),
      const AuditChange(label: 'Prazo', before: '30/06/2027', after: 'Sem prazo'),
    ]);
  });

  test('a goal moved to another account shows the names', () {
    final item = describeAudit(
      record(AuditAction.update, before: goal(accountId: 'a1'), after: goal(accountId: 'a2')),
      lookup,
    );

    expect(item.changes, [const AuditChange(label: 'Conta', before: 'Poupança', after: 'Nubank')]);
  });

  test('a goal that was archived', () {
    final item = describeAudit(
      record(
        AuditAction.update,
        before: goal(),
        after: goal(archivedAt: '2026-10-07T12:00:00+00:00'),
      ),
      lookup,
    );

    expect(item.changes, [const AuditChange(label: 'Arquivada', before: 'Não', after: 'Sim')]);
  });

  test('a goal that was removed with its account', () {
    final item = describeAudit(record(AuditAction.delete, before: goal()), lookup);

    expect(item.kind, AuditKind.deleted);
    expect(item.title, 'Meta excluída: Reserva');
  });
}
