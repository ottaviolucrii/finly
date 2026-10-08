import 'package:finly/core/money/money.dart';
import 'package:finly/features/audit/domain/audit_rules.dart';
import 'package:finly/features/audit/domain/entities/audit_item.dart';
import 'package:finly/features/audit/domain/entities/audit_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Noon in UTC: the same calendar day in almost every time zone.
  final when = DateTime.utc(2026, 10, 7, 12, 0);
  const noon = '2026-10-07T12:00:00+00:00';

  const lookup = AuditLookup(
    accountNames: {'a1': 'C6', 'a2': 'XP'},
    categoryNames: {'c1': 'Mercado', 'c2': 'Transporte'},
  );

  String money(int cents, [String currency = 'BRL']) => Money(cents, currency).format();

  Map<String, dynamic> transaction({
    String type = 'expense',
    String status = 'posted',
    int cents = 20000,
    String description = 'Combustível Lavras',
    String accountId = 'a1',
    String? categoryId = 'c1',
    String? deletedAt,
    String? invoiceId,
    String occurredAt = noon,
    String? notes,
    String updatedAt = '2026-10-07T12:00:00+00:00',
  }) {
    return {
      'id': 't1',
      'type': type,
      'status': status,
      'currency': 'BRL',
      'amount_cents': cents,
      'description': description,
      'account_id': accountId,
      'category_id': categoryId,
      'deleted_at': deletedAt,
      'invoice_id': invoiceId,
      'occurred_at': occurredAt,
      'notes': notes,
      'updated_at': updatedAt,
      'created_at': '2026-10-07T10:00:00+00:00',
      'workspace_id': 'w1',
    };
  }

  AuditRecord record({
    AuditAction action = AuditAction.update,
    String table = 'transactions',
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) {
    return AuditRecord(
      id: 'r1',
      tableName: table,
      recordId: 't1',
      action: action,
      oldData: before,
      newData: after,
      occurredAt: when,
    );
  }

  AuditItem describe(AuditRecord value) => describeAudit(value, lookup);

  group('AuditAction.fromDb', () {
    test('reads the labels of the database enum', () {
      expect(AuditAction.fromDb('INSERT'), AuditAction.insert);
      expect(AuditAction.fromDb('UPDATE'), AuditAction.update);
      expect(AuditAction.fromDb('DELETE'), AuditAction.delete);
    });

    test('refuses a label it does not know', () {
      expect(() => AuditAction.fromDb('TRUNCATE'), throwsArgumentError);
    });
  });

  group('the title', () {
    test('an expense that was created', () {
      final item = describe(record(action: AuditAction.insert, after: transaction()));

      expect(item.kind, AuditKind.created);
      expect(item.title, 'Saída criada: Combustível Lavras');
    });

    test('an income that was created', () {
      final item = describe(record(
        action: AuditAction.insert,
        after: transaction(type: 'income', description: 'Salário'),
      ));

      expect(item.title, 'Entrada criada: Salário');
    });

    test('the leg of a transfer is a transfer', () {
      final item = describe(record(
        action: AuditAction.insert,
        after: transaction(type: 'transfer_out', description: 'Para a reserva'),
      ));

      expect(item.title, 'Transferência criada: Para a reserva');
    });

    test('an edit', () {
      final item = describe(record(
        before: transaction(cents: 20000),
        after: transaction(cents: 25000),
      ));

      expect(item.kind, AuditKind.edited);
      expect(item.title, 'Saída alterada: Combustível Lavras');
    });

    test('a transaction sent to the trash is not "deleted"', () {
      final item = describe(record(
        before: transaction(),
        after: transaction(deletedAt: '2026-10-07T13:00:00+00:00'),
      ));

      expect(item.kind, AuditKind.trashed);
      expect(item.title, 'Saída enviada à lixeira: Combustível Lavras');
      expect(item.changes, isEmpty);
    });

    test('a transaction taken out of the trash', () {
      final item = describe(record(
        before: transaction(deletedAt: '2026-10-07T13:00:00+00:00'),
        after: transaction(),
      ));

      expect(item.kind, AuditKind.restored);
      expect(item.title, 'Saída restaurada: Combustível Lavras');
    });

    test('a row that was really removed', () {
      final item = describe(record(
        action: AuditAction.delete,
        table: 'budgets',
        before: {'id': 'b1', 'category_id': 'c1', 'limit_cents': 80000, 'currency': 'BRL'},
      ));

      expect(item.kind, AuditKind.deleted);
      expect(item.title, 'Orçamento excluído: Mercado');
    });

    test('a credit card is a card, not an account', () {
      final item = describe(record(
        action: AuditAction.insert,
        table: 'accounts',
        after: {'id': 'a2', 'name': 'XP', 'type': 'credit_card', 'currency': 'BRL'},
      ));

      expect(item.title, 'Cartão criado: XP');
    });

    test('a bank account', () {
      final item = describe(record(
        action: AuditAction.insert,
        table: 'accounts',
        after: {'id': 'a1', 'name': 'C6', 'type': 'checking', 'currency': 'BRL'},
      ));

      expect(item.title, 'Conta criada: C6');
    });

    test('the gender of the word follows the thing', () {
      String title(String table, Map<String, dynamic> data) =>
          describe(record(action: AuditAction.insert, table: table, after: data)).title;

      expect(title('categories', {'name': 'Lazer'}), 'Categoria criada: Lazer');
      expect(title('workspaces', {'name': 'Empresa'}), 'Workspace criado: Empresa');
      expect(title('recurring_transactions', {'description': 'Aluguel'}), 'Recorrência criada: Aluguel');
      expect(
        title('credit_card_invoices', {'due_date': '2026-11-10'}),
        'Fatura criada: vence em 10/11/2026',
      );
      expect(
        title('credit_card_details', {'account_id': 'a2', 'limit_cents': 500000}),
        'Dados do cartão criado: XP',
      );
    });

    test('a table it does not know still gets a title', () {
      final item = describe(record(action: AuditAction.insert, table: 'widgets', after: {'id': 'x'}));

      expect(item.title, 'widgets criado');
    });
  });

  group('the summary', () {
    test('a transaction has its type, value and date', () {
      final item = describe(record(action: AuditAction.insert, after: transaction()));

      expect(item.summary, 'Saída · ${money(20000)} · 07/10/2026');
    });

    test('a deleted row is described by the row as it was', () {
      final item = describe(record(
        action: AuditAction.delete,
        table: 'budgets',
        before: {'category_id': 'c1', 'limit_cents': 20000, 'currency': 'USD'},
      ));

      expect(item.summary, 'limite ${money(20000, 'USD')}');
    });

    test('a recurring item has its value and frequency', () {
      final item = describe(record(
        action: AuditAction.insert,
        table: 'recurring_transactions',
        after: {'description': 'Aluguel', 'amount_cents': 150000, 'currency': 'BRL', 'frequency': 'monthly'},
      ));

      expect(item.summary, '${money(150000)} · Mensal');
    });

    test('an account has its kind and currency', () {
      final item = describe(record(
        action: AuditAction.insert,
        table: 'accounts',
        after: {'name': 'XP', 'type': 'credit_card', 'currency': 'BRL'},
      ));

      expect(item.summary, 'Cartão de crédito · BRL');
    });

    test('a category has none', () {
      final item = describe(record(action: AuditAction.insert, table: 'categories', after: {'name': 'Lazer'}));

      expect(item.summary, isEmpty);
    });
  });

  group('the changes of an edit', () {
    test('moving a transaction to a card says which accounts', () {
      // The real record of an expense moved from C6 to the XP card.
      final item = describe(record(
        before: transaction(accountId: 'a1', invoiceId: null, updatedAt: '2026-10-07T11:00:00+00:00'),
        after: transaction(accountId: 'a2', invoiceId: 'i1', updatedAt: '2026-10-07T12:00:00+00:00'),
      ));

      expect(item.changes, [const AuditChange(label: 'Conta', before: 'C6', after: 'XP')]);
    });

    test('the amount is written as money', () {
      final item = describe(record(
        before: transaction(cents: 20000),
        after: transaction(cents: 25990),
      ));

      expect(
        item.changes,
        [AuditChange(label: 'Valor', before: money(20000), after: money(25990))],
      );
    });

    test('the date is written as a date', () {
      final item = describe(record(
        before: transaction(occurredAt: '2026-10-07T12:00:00+00:00'),
        after: transaction(occurredAt: '2026-10-09T12:00:00+00:00'),
      ));

      expect(item.changes, [const AuditChange(label: 'Data', before: '07/10/2026', after: '09/10/2026')]);
    });

    test('the status and the type are in Portuguese', () {
      final item = describe(record(
        before: transaction(status: 'pending'),
        after: transaction(status: 'posted'),
      ));

      expect(item.changes, [const AuditChange(label: 'Situação', before: 'Pendente', after: 'Confirmada')]);
    });

    test('a category is shown by name, and none is "Sem categoria"', () {
      final item = describe(record(
        before: transaction(categoryId: 'c1'),
        after: transaction(categoryId: null),
      ));

      expect(item.changes, [const AuditChange(label: 'Categoria', before: 'Mercado', after: 'Sem categoria')]);
    });

    test('a category or account that is gone is said so', () {
      final item = describe(record(
        before: transaction(categoryId: 'c1', accountId: 'a1'),
        after: transaction(categoryId: 'gone', accountId: 'gone2'),
      ));

      expect(item.changes.map((c) => c.after), containsAll(['Categoria removida', 'Conta removida']));
    });

    test('notes and descriptions', () {
      final item = describe(record(
        before: transaction(description: 'Gasolina', notes: null),
        after: transaction(description: 'Combustível', notes: 'posto da esquina'),
      ));

      expect(item.changes, [
        const AuditChange(label: 'Descrição', before: 'Gasolina', after: 'Combustível'),
        const AuditChange(label: 'Observações', before: '—', after: 'posto da esquina'),
      ]);
    });

    test('several changes come in a fixed, readable order', () {
      final item = describe(record(
        before: transaction(status: 'pending', cents: 100, description: 'A', occurredAt: '2026-10-01T12:00:00+00:00'),
        after: transaction(status: 'posted', cents: 200, description: 'B', occurredAt: '2026-10-02T12:00:00+00:00'),
      ));

      expect(item.changes.map((c) => c.label), ['Descrição', 'Valor', 'Data', 'Situação']);
    });

    test('what changes on every write is not shown', () {
      final item = describe(record(
        before: transaction(updatedAt: '2026-10-07T11:00:00+00:00'),
        after: transaction(updatedAt: '2026-10-07T12:00:00+00:00'),
      ));

      expect(item.changes, isEmpty);
    });

    test('an archived account says yes and no', () {
      final item = describe(record(
        table: 'accounts',
        before: {'name': 'C6', 'type': 'checking', 'archived_at': null},
        after: {'name': 'C6', 'type': 'checking', 'archived_at': '2026-10-07T12:00:00+00:00'},
      ));

      expect(item.changes, [const AuditChange(label: 'Arquivada', before: 'Não', after: 'Sim')]);
    });

    test('a recurring item that gets an end date', () {
      final item = describe(record(
        table: 'recurring_transactions',
        before: {'description': 'Aluguel', 'end_date': null, 'generated_count': 3},
        after: {'description': 'Aluguel', 'end_date': '2026-12-31', 'generated_count': 4},
      ));

      expect(item.changes, [const AuditChange(label: 'Fim', before: 'Sem fim', after: '31/12/2026')]);
    });

    test('a switch says yes and no', () {
      final item = describe(record(
        table: 'recurring_transactions',
        before: {'description': 'Aluguel', 'is_active': true},
        after: {'description': 'Aluguel', 'is_active': false},
      ));

      expect(item.changes, [const AuditChange(label: 'Ativa', before: 'Sim', after: 'Não')]);
    });

    test('the tax reserve is written as a percentage', () {
      final item = describe(record(
        table: 'workspaces',
        before: {'name': 'Empresa', 'tax_reserve_bps': 0},
        after: {'name': 'Empresa', 'tax_reserve_bps': 650},
      ));

      expect(item.changes, [const AuditChange(label: 'Reserva para impostos', before: '0%', after: '6,5%')]);
    });

    test('a budget limit is money in the currency of the row', () {
      final item = describe(record(
        table: 'budgets',
        before: {'category_id': 'c1', 'limit_cents': 80000, 'currency': 'BRL'},
        after: {'category_id': 'c1', 'limit_cents': 90000, 'currency': 'BRL'},
      ));

      expect(item.changes, [AuditChange(label: 'Limite', before: money(80000), after: money(90000))]);
    });

    test('a field it has no name for is left out', () {
      final item = describe(record(
        table: 'widgets',
        before: {'mystery': 1},
        after: {'mystery': 2},
      ));

      expect(item.changes, isEmpty);
    });

    test('only an edit has changes', () {
      final created = describe(record(action: AuditAction.insert, after: transaction()));
      final removed = describe(record(action: AuditAction.delete, table: 'accounts', before: {'name': 'C6'}));

      expect(created.changes, isEmpty);
      expect(removed.changes, isEmpty);
    });
  });

  group('the time', () {
    test('is on the phone clock', () {
      final item = describe(record(action: AuditAction.insert, after: transaction()));

      expect(item.occurredAt, when.toLocal());
    });

    test('auditTimeText is hours and minutes with two digits', () {
      expect(auditTimeText(DateTime(2026, 10, 7, 9, 5)), '09:05');
      expect(auditTimeText(DateTime(2026, 10, 7, 14, 32)), '14:32');
    });
  });

  test('keeps the id and the table of the line', () {
    final item = describe(record(action: AuditAction.insert, after: transaction()));

    expect(item.id, 'r1');
    expect(item.tableName, 'transactions');
  });
}
