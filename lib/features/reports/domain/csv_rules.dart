import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';

/// Brazilian spreadsheets use ";" (the comma is the decimal separator).
const String csvSeparator = ';';

const List<String> csvHeader = [
  'Data',
  'Descrição',
  'Tipo',
  'Status',
  'Categoria',
  'Conta',
  'Moeda',
  'Valor',
];

/// One text cell of the file. Text that starts with a character a spreadsheet
/// treats as a formula gets a leading apostrophe, and cells with a separator,
/// a quote or a line break are quoted.
String csvCell(String value) {
  var text = value;
  if (text.isNotEmpty && '=+-@\t\r'.contains(text[0])) text = "'$text";
  if (text.contains(csvSeparator) ||
      text.contains('"') ||
      text.contains('\n') ||
      text.contains('\r')) {
    text = '"${text.replaceAll('"', '""')}"';
  }
  return text;
}

/// "1234,50" or "-25,90": no thousands separator and no currency symbol, so a
/// spreadsheet reads it as a number. Built from the cents, with no `double`.
String formatCsvAmount(int cents, {required bool negative}) {
  final absolute = cents.abs();
  final whole = absolute ~/ 100;
  final fraction = (absolute % 100).toString().padLeft(2, '0');
  final sign = (negative && absolute != 0) ? '-' : '';
  return '$sign$whole,$fraction';
}

/// "2026-10-05". ISO dates read the same in every spreadsheet locale, while
/// "05/10/2026" is read as May 10 by a sheet set to the US locale.
String _isoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-$month-$day';
}

String _typeLabel(TransactionEntity transaction) {
  if (transaction.type.isTransfer) {
    return transaction.type.isCredit
        ? 'Transferência (entrada)'
        : 'Transferência (saída)';
  }
  return transaction.type == TransactionType.income ? 'Entrada' : 'Saída';
}

String _statusLabel(TransactionStatus status) {
  switch (status) {
    case TransactionStatus.pending:
      return 'Pendente';
    case TransactionStatus.posted:
      return 'Confirmada';
    case TransactionStatus.failed:
      return 'Falhou';
  }
}

/// The whole file as text: a header and one line per transaction, oldest
/// first, with Windows line breaks. The caller turns it into bytes (see
/// `encodeWindows1252`).
String buildTransactionsCsv(
  List<TransactionEntity> transactions,
  List<AccountEntity> accounts,
  List<CategoryEntity> categories,
) {
  final accountById = {for (final a in accounts) a.id: a};
  final categoryById = {for (final c in categories) c.id: c};

  final sorted = [...transactions]
    ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

  final lines = <String>[
    csvHeader.map(csvCell).join(csvSeparator),
    for (final t in sorted)
      [
        _isoDate(t.occurredAt),
        csvCell(t.description),
        csvCell(_typeLabel(t)),
        csvCell(_statusLabel(t.status)),
        csvCell(categoryById[t.categoryId]?.name ?? ''),
        csvCell(accountById[t.accountId]?.name ?? ''),
        csvCell(t.currency),
        // A number, not text: no formula guard here.
        formatCsvAmount(t.amountCents, negative: !t.type.isCredit),
      ].join(csvSeparator),
  ];

  return '${lines.join('\r\n')}\r\n';
}