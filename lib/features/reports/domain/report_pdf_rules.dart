import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/reports/domain/report_rules.dart';

const List<String> _monthNames = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// "Outubro de 2026": the title of the report.
String pdfMonthTitle(DateTime month) {
  final name = _monthNames[month.month - 1];
  return '${name[0].toUpperCase()}${name.substring(1)} de ${month.year}';
}

/// "finly-relatorio-2026-10.pdf".
String pdfFileName(DateTime month) {
  final number = month.month.toString().padLeft(2, '0');
  return 'finly-relatorio-${month.year}-$number.pdf';
}

/// "+ 12%" style comparison with the month before, in plain characters: the
/// standard PDF font has no arrows, so a sign says the direction.
String pdfChangeText(int current, int previous) {
  final change = percentChange(current, previous);
  if (change == null) return current == 0 ? '-' : 'sem dados';
  if (change == 0) return '0%';
  return '${change > 0 ? '+' : '-'}${change.abs()}%';
}

/// "R$ 1.234,56", or "+ R$ 1.234,56" for a positive result.
String pdfSignedMoney(int cents, String currency) {
  final text = Money(cents, currency).format();
  return cents > 0 ? '+ $text' : text;
}

/// "gerado em 07/10/2026 às 09:05".
String pdfGeneratedText(DateTime at) {
  final hour = at.hour.toString().padLeft(2, '0');
  final minute = at.minute.toString().padLeft(2, '0');
  return 'gerado em ${formatDateBr(at)} às $hour:$minute';
}
