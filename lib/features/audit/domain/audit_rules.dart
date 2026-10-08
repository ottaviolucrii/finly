import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/core/utils/iso_date.dart';
import 'package:finly/features/audit/domain/entities/audit_item.dart';
import 'package:finly/features/audit/domain/entities/audit_record.dart';

/// What a table is called, and whether the word is feminine (to say "criada" or
/// "criado").
class _Entity {
  final String name;
  final bool feminine;

  const _Entity(this.name, this.feminine);
}

_Entity _entityOf(String table, Map<String, dynamic> data) {
  switch (table) {
    case 'transactions':
      final type = data['type'];
      if (type == 'income') return const _Entity('Entrada', true);
      if (type == 'expense') return const _Entity('Saída', true);
      return const _Entity('Transferência', true);
    case 'transfers':
      return const _Entity('Transferência', true);
    case 'accounts':
      return data['type'] == 'credit_card'
          ? const _Entity('Cartão', false)
          : const _Entity('Conta', true);
    case 'categories':
      return const _Entity('Categoria', true);
    case 'budgets':
      return const _Entity('Orçamento', false);
    case 'recurring_transactions':
      return const _Entity('Recorrência', true);
    case 'workspaces':
      return const _Entity('Workspace', false);
    case 'credit_card_details':
      return const _Entity('Dados do cartão', false);
    case 'credit_card_invoices':
      return const _Entity('Fatura', true);
    default:
      return _Entity(table, false);
  }
}

String _verb(AuditKind kind, bool feminine) {
  switch (kind) {
    case AuditKind.created:
      return feminine ? 'criada' : 'criado';
    case AuditKind.edited:
      return feminine ? 'alterada' : 'alterado';
    case AuditKind.deleted:
      return feminine ? 'excluída' : 'excluído';
    case AuditKind.trashed:
      return feminine ? 'enviada à lixeira' : 'enviado à lixeira';
    case AuditKind.restored:
      return feminine ? 'restaurada' : 'restaurado';
  }
}

/// Fields that change on every write or that say nothing to a person.
const Set<String> _hiddenFields = {
  'id',
  'workspace_id',
  'created_at',
  'updated_at',
  'invoice_id',
  'recurring_id',
  'transfer_id',
  'installment_group_id',
  'installment_number',
  'installment_total',
  'scheduled_for',
  'generated_count',
  'receipt_path',
  'deleted_at',
  'category_kind',
  'currency',
};

const Map<String, String> _labels = {
  'description': 'Descrição',
  'amount_cents': 'Valor',
  'occurred_at': 'Data',
  'status': 'Situação',
  'notes': 'Observações',
  'category_id': 'Categoria',
  'account_id': 'Conta',
  'type': 'Tipo',
  'name': 'Nome',
  'icon': 'Ícone',
  'color': 'Cor',
  'is_tax': 'É imposto',
  'archived_at': 'Arquivada',
  'limit_cents': 'Limite',
  'effective_from': 'Vale a partir de',
  'opening_balance_cents': 'Saldo inicial',
  'frequency': 'Frequência',
  'interval_count': 'Intervalo',
  'start_date': 'Início',
  'end_date': 'Fim',
  'lead_days': 'Avisar com antecedência (dias)',
  'is_active': 'Ativa',
  'closing_day': 'Dia de fechamento',
  'due_day': 'Dia de vencimento',
  'due_date': 'Vencimento',
  'tax_reserve_bps': 'Reserva para impostos',
  'base_currency': 'Moeda base',
  'tax_id': 'CPF/CNPJ',
};

const Map<String, String> _statuses = {
  'posted': 'Confirmada',
  'pending': 'Pendente',
  'failed': 'Falhou',
  'open': 'Aberta',
  'closed': 'Fechada',
  'paid': 'Paga',
};

const Map<String, String> _types = {
  'income': 'Entrada',
  'expense': 'Saída',
  'transfer_in': 'Transferência recebida',
  'transfer_out': 'Transferência enviada',
  'checking': 'Conta corrente',
  'savings': 'Poupança',
  'investment': 'Investimento',
  'credit_card': 'Cartão de crédito',
  'cash': 'Dinheiro',
  'personal': 'Pessoal',
  'business': 'Empresa',
};

const Map<String, String> _frequencies = {
  'daily': 'Diária',
  'weekly': 'Semanal',
  'monthly': 'Mensal',
  'yearly': 'Anual',
};

/// "6,5%": basis points as a percentage.
String _percentOfBps(int bps) {
  final whole = bps ~/ 100;
  final fraction = bps % 100;
  if (fraction == 0) return '$whole%';

  var digits = fraction.toString().padLeft(2, '0');
  if (digits.endsWith('0')) digits = digits.substring(0, 1);
  return '$whole,$digits%';
}

String _two(int value) => value.toString().padLeft(2, '0');

/// A date or a timestamp of the log as "07/10/2026". A timestamp is read on the
/// phone's clock; a plain date has no time zone to shift.
String _dateText(String value) {
  try {
    if (value.length == 10) return formatDateBr(parseIsoDate(value));
    return formatDateBr(DateTime.parse(value).toLocal());
  } catch (_) {
    return value;
  }
}

/// One value of a field, written for a person.
String _valueText(
  String key,
  dynamic value,
  AuditLookup lookup,
  String currency,
) {
  if (key == 'archived_at') return value == null ? 'Não' : 'Sim';
  if (key == 'category_id') {
    if (value == null) return 'Sem categoria';
    return lookup.categoryNames[value] ?? 'Categoria removida';
  }
  if (key == 'account_id') {
    if (value == null) return '—';
    return lookup.accountNames[value] ?? 'Conta removida';
  }
  if (key == 'end_date' && value == null) return 'Sem fim';
  if (value == null) return '—';

  if (value is bool) return value ? 'Sim' : 'Não';

  if (key.endsWith('_cents') && value is num) {
    return Money(value.toInt(), currency).format();
  }
  if (key == 'tax_reserve_bps' && value is num) return _percentOfBps(value.toInt());
  if (value is String) {
    if (const {'occurred_at', 'start_date', 'end_date', 'effective_from', 'due_date'}.contains(key)) {
      return _dateText(value);
    }
    if (key == 'status') return _statuses[value] ?? value;
    if (key == 'type') return _types[value] ?? value;
    if (key == 'frequency') return _frequencies[value] ?? value;
  }
  return value.toString();
}

String _nameOf(String table, Map<String, dynamic> data, AuditLookup lookup) {
  switch (table) {
    case 'transactions':
    case 'recurring_transactions':
      return (data['description'] ?? '').toString();
    case 'accounts':
    case 'categories':
    case 'workspaces':
      return (data['name'] ?? '').toString();
    case 'budgets':
      return lookup.categoryNames[data['category_id']] ?? '';
    case 'credit_card_details':
      return lookup.accountNames[data['account_id']] ?? '';
    case 'credit_card_invoices':
      final due = data['due_date'];
      return due is String ? 'vence em ${_dateText(due)}' : '';
    default:
      return '';
  }
}

String _summaryOf(String table, Map<String, dynamic> data) {
  final currency = (data['currency'] ?? 'BRL').toString();
  String money(String key) {
    final cents = data[key];
    return cents is num ? Money(cents.toInt(), currency).format() : '';
  }

  final parts = <String>[];
  switch (table) {
    case 'transactions':
      parts
        ..add(_types[data['type']] ?? '')
        ..add(money('amount_cents'))
        ..add(data['occurred_at'] is String ? _dateText(data['occurred_at'] as String) : '');
    case 'recurring_transactions':
      parts
        ..add(money('amount_cents'))
        ..add(_frequencies[data['frequency']] ?? '');
    case 'budgets':
      parts.add('limite ${money('limit_cents')}');
    case 'accounts':
      parts
        ..add(_types[data['type']] ?? '')
        ..add(currency);
    case 'credit_card_details':
      parts.add('limite ${money('limit_cents')}');
  }
  return parts.where((part) => part.isNotEmpty).join(' · ');
}

List<AuditChange> _changesOf(
  Map<String, dynamic> before,
  Map<String, dynamic> after,
  AuditLookup lookup,
) {
  final currency = (after['currency'] ?? before['currency'] ?? 'BRL').toString();
  final keys = <String>{...before.keys, ...after.keys};
  final changes = <AuditChange>[];

  for (final key in keys) {
    if (_hiddenFields.contains(key)) continue;
    final label = _labels[key];
    if (label == null) continue;

    final was = before[key];
    final now = after[key];
    if (was == now) continue;

    changes.add(
      AuditChange(
        label: label,
        before: _valueText(key, was, lookup, currency),
        after: _valueText(key, now, lookup, currency),
      ),
    );
  }

  // A stable order: the order of the labels above, not of the database.
  final order = _labels.values.toList();
  changes.sort((a, b) => order.indexOf(a.label).compareTo(order.indexOf(b.label)));
  return changes;
}

/// Turns a line of the audit log into a sentence a person can read.
AuditItem describeAudit(AuditRecord record, AuditLookup lookup) {
  final before = record.oldData ?? const <String, dynamic>{};
  final after = record.newData ?? const <String, dynamic>{};
  final data = record.newData ?? record.oldData ?? const <String, dynamic>{};

  var kind = switch (record.action) {
    AuditAction.insert => AuditKind.created,
    AuditAction.update => AuditKind.edited,
    AuditAction.delete => AuditKind.deleted,
  };

  // A transaction is not removed: it goes to the trash (deleted_at is set), and
  // comes back when deleted_at is cleared.
  if (record.action == AuditAction.update && record.tableName == 'transactions') {
    final wasDeleted = before['deleted_at'] != null;
    final isDeleted = after['deleted_at'] != null;
    if (!wasDeleted && isDeleted) kind = AuditKind.trashed;
    if (wasDeleted && !isDeleted) kind = AuditKind.restored;
  }

  final entity = _entityOf(record.tableName, data);
  final name = _nameOf(record.tableName, data, lookup);
  final title = '${entity.name} ${_verb(kind, entity.feminine)}${name.isEmpty ? '' : ': $name'}';

  return AuditItem(
    id: record.id,
    tableName: record.tableName,
    kind: kind,
    title: title,
    summary: _summaryOf(record.tableName, data),
    changes: kind == AuditKind.edited ? _changesOf(before, after, lookup) : const [],
    occurredAt: record.occurredAt.toLocal(),
  );
}

/// "14:32".
String auditTimeText(DateTime at) => '${_two(at.hour)}:${_two(at.minute)}';
