import 'package:equatable/equatable.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/features/reports/domain/entities/monthly_report.dart';
import 'package:finly/features/reports/domain/report_rules.dart';

const _monthNames = [
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

/// "setembro".
String monthName(DateTime month) => _monthNames[month.month - 1];

/// "Setembro".
String monthNameCapitalized(DateTime month) {
  final name = monthName(month);
  return name[0].toUpperCase() + name.substring(1);
}

/// What kind of fact a line of the summary tells (the screen picks its icon).
enum SummaryLineKind { flow, net, comparison, rise, top }

class SummaryLine extends Equatable {
  final SummaryLineKind kind;
  final String text;

  const SummaryLine(this.kind, this.text);

  @override
  List<Object?> get props => [kind, text];
}

/// A month told in a few sentences, worked out from the monthly report: no
/// AI and nothing leaves the phone.
class MonthSummary extends Equatable {
  /// The first day of the month.
  final DateTime month;
  final String currency;
  final int incomeCents;
  final int expenseCents;
  final int netCents;

  /// The one sentence for the card: "Setembro: você gastou 12% a menos que no
  /// mês anterior e sobrou R$ 800,00."
  final String headline;
  final List<SummaryLine> lines;

  const MonthSummary({
    required this.month,
    required this.currency,
    required this.incomeCents,
    required this.expenseCents,
    required this.netCents,
    required this.headline,
    required this.lines,
  });

  /// Nothing came in or went out: there is nothing to tell.
  bool get isEmpty => incomeCents == 0 && expenseCents == 0;

  @override
  List<Object?> get props => [month, currency, incomeCents, expenseCents, netCents, headline, lines];
}

/// A category has to grow by at least this much (R$ 20,00) and 10% to be
/// told as "where it grew the most".
const _minRiseCents = 2000;
const _minRisePercent = 10;

/// The summary of [report]'s month, in reais when there are reais (otherwise
/// the first currency); null when the report has no movement at all.
MonthSummary? monthSummaryOf(MonthlyReport report) {
  if (report.byCurrency.isEmpty) return null;
  final r = report.byCurrency.firstWhere(
    (c) => c.currency == 'BRL',
    orElse: () => report.byCurrency.first,
  );
  String money(int cents) => Money(cents.abs(), r.currency).format();

  final month = DateTime(report.month.year, report.month.month);
  final net = r.netCents;
  final percent = percentChange(r.expenseCents, r.previousExpenseCents);

  // the headline
  final String spent;
  if (r.expenseCents == 0) {
    spent = 'você não teve despesas';
  } else if (percent != null && percent != 0) {
    spent = 'você gastou ${percent.abs()}% ${percent > 0 ? 'a mais' : 'a menos'} que no mês anterior';
  } else {
    spent = 'você gastou ${money(r.expenseCents)}';
  }
  final left = net > 0
      ? ' e sobrou ${money(net)}'
      : net < 0
          ? ' e faltou ${money(net)}'
          : '';
  final headline = '${monthNameCapitalized(month)}: $spent$left.';

  // the lines
  final lines = <SummaryLine>[
    SummaryLine(SummaryLineKind.flow, 'Entraram ${money(r.incomeCents)} e saíram ${money(r.expenseCents)}.'),
    if (net > 0) SummaryLine(SummaryLineKind.net, 'Sobrou ${money(net)}.'),
    if (net < 0) SummaryLine(SummaryLineKind.net, 'Faltou ${money(net)}.'),
  ];

  if (percent != null) {
    lines.add(SummaryLine(
      SummaryLineKind.comparison,
      percent == 0
          ? 'Você gastou o mesmo que no mês anterior.'
          : 'Você gastou ${percent.abs()}% ${percent > 0 ? 'a mais' : 'a menos'} que no mês anterior '
              '(${money(r.previousExpenseCents)}).',
    ));
  }

  final real = [for (final c in r.categories) if (!c.isOther && c.spentCents > 0) c];

  CategoryChange? rise;
  for (final c in real) {
    final diff = c.spentCents - c.previousCents;
    final pct = percentChange(c.spentCents, c.previousCents);
    if (c.previousCents > 0 && diff >= _minRiseCents && pct != null && pct >= _minRisePercent) {
      if (rise == null || diff > rise.spentCents - rise.previousCents) rise = c;
    }
  }
  if (rise != null) {
    lines.add(SummaryLine(
      SummaryLineKind.rise,
      'Onde mais cresceu: ${rise.name}, de ${money(rise.previousCents)} para ${money(rise.spentCents)}.',
    ));
  }

  if (real.isNotEmpty && r.expenseCents > 0) {
    final top = real.reduce((a, b) => b.spentCents > a.spentCents ? b : a);
    final share = (top.spentCents * 100 / r.expenseCents).round().clamp(0, 100);
    lines.add(SummaryLine(
      SummaryLineKind.top,
      'Onde mais gastou: ${top.name}, ${money(top.spentCents)} ($share% das despesas).',
    ));
  }

  return MonthSummary(
    month: month,
    currency: r.currency,
    incomeCents: r.incomeCents,
    expenseCents: r.expenseCents,
    netCents: net,
    headline: headline,
    lines: lines,
  );
}
