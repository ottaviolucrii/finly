import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/forecast/domain/entities/forecast_items.dart';
import 'package:finly/features/forecast/domain/forecast_rules.dart';

/// The headline of a movement (Portuguese for now; replaced by proper
/// localisation in a later phase).
String forecastEventTitle(ForecastItem item) {
  switch (item.kind) {
    case ForecastKind.invoice:
      return 'Fatura ${item.label}';
    case ForecastKind.pending:
    case ForecastKind.recurring:
      return item.label;
  }
}

/// Where a movement comes from, in a few words.
String forecastKindLabel(ForecastKind kind) {
  switch (kind) {
    case ForecastKind.pending:
      return 'Lançamento pendente';
    case ForecastKind.recurring:
      return 'Recorrente';
    case ForecastKind.invoice:
      return 'Fatura do cartão';
  }
}

/// "Em 30 dias".
String forecastHorizonLabel(int days) => 'Em $days dias';

/// The warning about a negative balance, or null when the balance stays
/// above zero.
String? forecastWarning(Forecast forecast, DateTime today) {
  final date = forecast.firstNegativeDate;
  if (date == null) return null;

  final days = dayIndex(dateOnly(today), date);
  final when = days <= 0
      ? 'hoje'
      : (days == 1 ? 'amanhã (${formatDateBr(date)})' : 'em $days dias (${formatDateBr(date)})');
  return 'O saldo pode ficar negativo $when.';
}

/// How the numbers are made, for the explanation card.
const List<String> forecastExplanation = [
  'Parte do saldo confirmado das suas contas, sem os cartões de crédito.',
  'Soma os lançamentos pendentes, dia a dia. Os atrasados contam hoje.',
  'Inclui os lançamentos recorrentes que ainda vão ser gerados.',
  'Desconta as faturas de cartão em aberto no dia do vencimento, com o total de hoje.',
  'Não inclui gastos que você ainda não lançou, rendimentos nem mudanças de data. É uma estimativa.',
];
