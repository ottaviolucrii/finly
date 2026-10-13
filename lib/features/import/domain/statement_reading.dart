import 'dart:convert';

import 'package:finly/features/import/domain/statement_line.dart';

/// The text of a statement file: UTF-8 when it is, otherwise Windows-1252 /
/// Latin-1 (what many Brazilian banks still use), so "Padaria Pão" reads right.
String decodeStatement(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

/// Reads an OFX or a CSV, by its content (the name can lie).
StatementFile readStatement(String text) {
  final upper = text.length > 4000 ? text.substring(0, 4000).toUpperCase() : text.toUpperCase();
  if (upper.contains('<OFX>') || upper.contains('OFXHEADER') || upper.contains('<STMTTRN>')) return readOfx(text);
  return readCsv(text);
}

/// An amount like "-1.234,56", "1234.56", "R$ 12,30" or "(12,30)" in cents;
/// null when it is not an amount.
int? parseAmountCents(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'[R$\s\u00A0]'), '');
  if (s.isEmpty) return null;
  var negative = false;
  if (s.startsWith('(') && s.endsWith(')')) {
    negative = true;
    s = s.substring(1, s.length - 1);
  }
  if (s.startsWith('-')) {
    negative = !negative;
    s = s.substring(1);
  } else if (s.startsWith('+')) {
    s = s.substring(1);
  }
  if (s.endsWith('-')) {
    negative = !negative;
    s = s.substring(0, s.length - 1);
  }
  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  String whole;
  var fraction = '';
  if (lastComma >= 0 && lastDot >= 0) {
    final decimal = lastComma > lastDot ? ',' : '.';
    final at = s.lastIndexOf(decimal);
    whole = s.substring(0, at).replaceAll(RegExp(r'[.,]'), '');
    fraction = s.substring(at + 1);
  } else if (lastComma >= 0) {
    whole = s.substring(0, lastComma).replaceAll(',', '');
    fraction = s.substring(lastComma + 1);
  } else if (lastDot >= 0 && s.length - lastDot - 1 <= 2) {
    whole = s.substring(0, lastDot).replaceAll('.', '');
    fraction = s.substring(lastDot + 1);
  } else {
    whole = s.replaceAll('.', '');
  }
  if (!RegExp(r'^\d+$').hasMatch(whole.isEmpty ? '0' : whole) || !RegExp(r'^\d{0,2}$').hasMatch(fraction)) return null;
  final cents = int.parse(whole.isEmpty ? '0' : whole) * 100 + int.parse(fraction.padRight(2, '0').isEmpty ? '0' : fraction.padRight(2, '0'));
  return negative ? -cents : cents;
}

/// A date like "25/10/2026", "25/10/26", "2026-10-25" or "25-10-2026".
DateTime? parseStatementDate(String raw) {
  final s = raw.trim();
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (iso != null) return _date(int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!));
  final br = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})').firstMatch(s);
  if (br != null) {
    var year = int.parse(br[3]!);
    if (year < 100) year += 2000;
    return _date(year, int.parse(br[2]!), int.parse(br[1]!));
  }
  return null;
}

DateTime? _date(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime(year, month, day);
  return date.month == month ? date : null;
}

/// Reads the transactions of an OFX (the old SGML kind, where tags may not
/// close, and the XML kind).
StatementFile readOfx(String text) {
  final upper = text.toUpperCase();
  final looksLikeCard = upper.contains('<CCSTMTRS>') || upper.contains('<CREDITCARDMSGSRSV1>');
  final lines = <StatementLine>[];
  var skipped = 0;
  final blocks = RegExp(r'<STMTTRN>(.*?)(?=</STMTTRN>|<STMTTRN>|</BANKTRANLIST>)', caseSensitive: false, dotAll: true)
      .allMatches(text);
  String? field(String block, String tag) {
    final m = RegExp('<$tag>([^<\\r\\n]*)', caseSensitive: false).firstMatch(block);
    final value = m?[1]?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  for (final m in blocks) {
    final block = m[1]!;
    final posted = field(block, 'DTPOSTED');
    final amount = field(block, 'TRNAMT');
    final memo = field(block, 'MEMO');
    final name = field(block, 'NAME');
    final description = _clean(memo ?? name ?? '');
    final date = (posted != null && posted.length >= 8)
        ? _date(int.tryParse(posted.substring(0, 4)) ?? 0, int.tryParse(posted.substring(4, 6)) ?? 0,
            int.tryParse(posted.substring(6, 8)) ?? 0)
        : null;
    final cents = amount == null ? null : parseAmountCents(amount);
    if (date == null || cents == null || cents == 0 || description.isEmpty) {
      skipped++;
      continue;
    }
    lines.add(StatementLine(date: date, amountCents: cents, description: description, externalId: field(block, 'FITID')));
  }
  return StatementFile(lines: lines, looksLikeCard: looksLikeCard, skipped: skipped);
}

String _clean(String text) => text
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// The words a bank uses for each column of a CSV.
const _dateNames = ['data', 'date', 'dt', 'data lancamento', 'data movimento', 'data da compra'];
const _descriptionNames = [
  'descricao', 'description', 'title', 'titulo', 'historico', 'lancamento', 'estabelecimento', 'memo', 'detalhe',
];
const _amountNames = ['valor', 'amount', 'quantia', 'value', 'valor (r\$)', 'valor r\$'];
const _idNames = ['identificador', 'id', 'fitid'];

String _plain(String text) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const to = 'aaaaaeeeeiiiiooooouuuuc';
  final out = StringBuffer();
  for (final c in text.toLowerCase().trim().split('')) {
    final i = from.indexOf(c);
    out.write(i < 0 ? c : to[i]);
  }
  return out.toString();
}

/// Splits one CSV line, honoring quotes ("Mercado, centro").
List<String> splitCsvLine(String line, String separator) {
  final cells = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (c == separator && !quoted) {
      cells.add(cell.toString().trim());
      cell.clear();
    } else {
      cell.write(c);
    }
  }
  cells.add(cell.toString().trim());
  return cells;
}

/// Reads a CSV: finds the header, guesses the date, description and amount
/// columns, and reads the lines.
StatementFile readCsv(String text) {
  final rows = const LineSplitter().convert(text).where((l) => l.trim().isNotEmpty).toList();
  if (rows.isEmpty) return const StatementFile(lines: []);
  final sample = rows.take(5).join('\n');
  final separator = [';', ',', '\t'].reduce((a, b) => a.allMatches(sample).length >= b.allMatches(sample).length ? a : b);

  int? find(List<String> header, List<String> names) {
    for (var i = 0; i < header.length; i++) {
      if (names.contains(header[i])) return i;
    }
    for (var i = 0; i < header.length; i++) {
      if (names.any((n) => header[i].startsWith(n))) return i;
    }
    return null;
  }

  var headerAt = -1;
  int? dateCol, descCol, amountCol, idCol;
  for (var r = 0; r < rows.length && r < 15; r++) {
    final header = splitCsvLine(rows[r], separator).map(_plain).toList();
    final d = find(header, _dateNames), t = find(header, _descriptionNames), a = find(header, _amountNames);
    if (d != null && t != null && a != null) {
      headerAt = r;
      dateCol = d;
      descCol = t;
      amountCol = a;
      idCol = find(header, _idNames);
      break;
    }
  }
  if (headerAt < 0) return StatementFile(lines: const [], skipped: rows.length);

  final lines = <StatementLine>[];
  var skipped = 0;
  for (final row in rows.skip(headerAt + 1)) {
    final cells = splitCsvLine(row, separator);
    String cell(int? i) => (i != null && i < cells.length) ? cells[i] : '';
    final date = parseStatementDate(cell(dateCol));
    final cents = parseAmountCents(cell(amountCol));
    final description = _clean(cell(descCol));
    if (date == null || cents == null || cents == 0 || description.isEmpty) {
      skipped++;
      continue;
    }
    final id = cell(idCol);
    lines.add(StatementLine(date: date, amountCents: cents, description: description, externalId: id.isEmpty ? null : id));
  }
  return StatementFile(lines: lines, skipped: skipped);
}
