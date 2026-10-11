import 'package:finly/core/money/money.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/dashboard/presentation/widgets/home/home_cards.dart';
import 'package:finly/features/forecast/domain/entities/forecast_items.dart';
import 'package:finly/features/goals/domain/entities/goal_progress.dart';
import 'package:flutter/material.dart';

/// The balance the forecast expects on the last day of the month of [today]
/// (or on its last day, when it ends before that).
int endOfMonthBalance(Forecast forecast, DateTime today) {
  final last = DateTime(today.year, today.month + 1, 0);
  var balance = forecast.points.first.balanceCents;
  for (final point in forecast.points) {
    if (point.date.isAfter(last)) break;
    balance = point.balanceCents;
  }
  return balance;
}

/// What was spent and the limits of the budgets, in their first currency
/// (budgets in other currencies are left out of the sum).
({String currency, int spentCents, int limitCents, int overCount}) budgetTotals(List<BudgetProgress> items) {
  if (items.isEmpty) return (currency: 'BRL', spentCents: 0, limitCents: 0, overCount: 0);
  final currency = items.first.currency;
  var spent = 0, limit = 0, over = 0;
  for (final item in items) {
    if (item.currency != currency) continue;
    spent += item.spentCents;
    limit += item.limitCents;
    if (item.level == BudgetLevel.over) over++;
  }
  return (currency: currency, spentCents: spent, limitCents: limit, overCount: over);
}

/// The budgets closest to their limit first.
List<BudgetProgress> closestToLimit(List<BudgetProgress> items, {int count = 3}) {
  final sorted = [...items]..sort((a, b) => b.ratio.compareTo(a.ratio));
  return sorted.take(count).toList();
}

/// A small card with a title and a link, used by the three sections.
class _PlanCard extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget child;

  const _PlanCard({required this.title, this.action, this.onAction, required this.child});

  @override
  Widget build(BuildContext context) {
    return HomeSection(title: title, actionLabel: action, onAction: onAction, child: child);
  }
}

/// The forecast for the next 30 days: a line of the balance, the lowest day
/// marked in gold, and the balance expected at the end of the month.
class PlanForecastCard extends StatelessWidget {
  /// Null while loading or when it failed (see [failed]).
  final Forecast? forecast;
  final DateTime today;
  final bool failed;
  final VoidCallback onOpen;

  const PlanForecastCard({
    super.key,
    required this.forecast,
    required this.today,
    required this.onOpen,
    this.failed = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final full = forecast;

    if (full == null) {
      return _PlanCard(
        title: 'Previsão',
        action: 'Abrir',
        onAction: onOpen,
        child: failed
            ? Text('Não foi possível calcular a previsão agora.', style: text.bodyMedium)
            : const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
      );
    }

    final next = full.limitTo(30);
    final lowest = next.lowest;
    final negative = next.firstNegativeDate;
    final end = endOfMonthBalance(full, today);
    final lowestIndex = next.points.indexOf(lowest);
    String money(int cents) => Money(cents, full.currency).format();

    return _PlanCard(
      title: 'Previsão',
      action: 'Ver completa',
      onAction: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Fim do mês', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          Text(
            money(end),
            style: text.titleLarge?.copyWith(color: end < 0 ? scheme.error : null),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Saldo nos próximos 30 dias: menor saldo ${money(lowest.balanceCents)} '
                'em ${formatDateBr(lowest.date)}',
            excludeSemantics: true,
            child: SizedBox(
              height: 96,
              child: CustomPaint(
                painter: BalanceLinePainter(
                  values: [for (final point in next.points) point.balanceCents],
                  highlight: lowestIndex,
                  line: scheme.primary,
                  dot: AppColors.gold,
                  baseline: scheme.outlineVariant,
                  zero: scheme.error,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Hoje', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              const Spacer(),
              Text('30 dias', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            negative != null
                ? 'Fica negativo em ${formatDateBr(negative)}'
                : 'Menor saldo: ${money(lowest.balanceCents)} em ${formatDateBr(lowest.date)}',
            style: text.bodyMedium?.copyWith(
              color: negative != null ? scheme.error : null,
              fontWeight: negative != null ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws a line through [values] from left to right, a thin base line, a red
/// line at zero when the values go below it, and a dot on [highlight].
class BalanceLinePainter extends CustomPainter {
  final List<int> values;
  final int highlight;
  final Color line;
  final Color dot;
  final Color baseline;
  final Color zero;

  const BalanceLinePainter({
    required this.values,
    required this.highlight,
    required this.line,
    required this.dot,
    required this.baseline,
    required this.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.width <= 0 || size.height <= 0) return;

    var low = values.first, high = values.first;
    for (final value in values) {
      if (value < low) low = value;
      if (value > high) high = value;
    }
    final span = (high - low) == 0 ? 1 : high - low;
    const top = 6.0;
    final bottom = size.height - 6;
    double y(int value) => bottom - (value - low) / span * (bottom - top);
    double x(int index) => values.length == 1 ? 0 : index / (values.length - 1) * size.width;

    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()..color = baseline..strokeWidth = 1,
    );
    if (low < 0 && high > 0) {
      canvas.drawLine(
        Offset(0, y(0)),
        Offset(size.width, y(0)),
        Paint()..color = zero.withValues(alpha: 0.6)..strokeWidth = 1,
      );
    }

    final path = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    if (highlight >= 0 && highlight < values.length) {
      canvas.drawCircle(Offset(x(highlight), y(values[highlight])), 5, Paint()..color = dot);
    }
  }

  @override
  bool shouldRepaint(BalanceLinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.highlight != highlight || oldDelegate.line != line;
}

/// The budgets of the month: a ring with the share of all limits already
/// spent, and the categories closest to their limit.
class PlanBudgetsCard extends StatelessWidget {
  /// Null while loading.
  final List<BudgetProgress>? items;
  final DateTime month;
  final DateTime today;
  final VoidCallback onOpen;

  const PlanBudgetsCard({
    super.key,
    required this.items,
    required this.month,
    required this.today,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final list = items;
    final title = 'Orçamentos de ${monthName(month).toLowerCase()}';

    if (list == null) {
      return _PlanCard(
        title: title,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (list.isEmpty) {
      return _PlanCard(
        title: title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Defina quanto quer gastar em cada categoria e acompanhe aqui.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onOpen, child: const Text('Criar orçamento')),
          ],
        ),
      );
    }

    final totals = budgetTotals(list);
    final ratio = totals.limitCents <= 0 ? 0.0 : totals.spentCents / totals.limitCents;
    final percent = (ratio * 100).floor();
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final daysLeft = DateTime(lastDay.year, lastDay.month, lastDay.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    final sameMonth = today.year == month.year && today.month == month.month;
    final details = [
      if (sameMonth) daysLeft == 0 ? 'Último dia do mês' : 'Faltam $daysLeft ${daysLeft == 1 ? 'dia' : 'dias'}',
      if (totals.overCount > 0) '${totals.overCount} ${totals.overCount == 1 ? 'categoria passou' : 'categorias passaram'}',
    ].join(' · ');
    String money(int cents) => Money(cents, totals.currency).format();

    return _PlanCard(
      title: title,
      action: 'Ver todos',
      onAction: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      strokeWidth: 8,
                      color: ratio > 1 ? scheme.error : scheme.primary,
                      backgroundColor: dark ? AppColors.borderDark : AppColors.track,
                    ),
                    Center(child: Text('$percent%', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${money(totals.spentCents)} de ${money(totals.limitCents)}',
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (details.isNotEmpty)
                      Text(details, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final item in closestToLimit(list)) ...[
            Row(
              children: [
                Expanded(
                  child: Text(item.category.name, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                ),
                Text(
                  item.level == BudgetLevel.over
                      ? '${item.spent.format()} de ${item.limit.format()} · passou'
                      : '${item.spent.format()} de ${item.limit.format()}',
                  style: text.bodySmall?.copyWith(
                    color: item.level == BudgetLevel.over ? scheme.error : scheme.onSurfaceVariant,
                    fontWeight: item.level == BudgetLevel.over ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ProgressLine(
              ratio: item.ratio,
              color: switch (item.level) {
                BudgetLevel.over => scheme.error,
                BudgetLevel.warning => AppColors.gold,
                BudgetLevel.normal => scheme.primary,
              },
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// One goal as a small card: a ring with its share and the amounts.
class PlanGoalTile extends StatelessWidget {
  final GoalProgress goal;
  final VoidCallback onTap;

  const PlanGoalTile({super.key, required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final currency = goal.goal.currency;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: goal.percent / 100,
                      strokeWidth: 6,
                      color: goal.achieved ? AppColors.positive : AppColors.gold,
                      backgroundColor: dark ? AppColors.borderDark : AppColors.track,
                    ),
                    Center(child: Text('${goal.percent}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(goal.goal.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              Text(
                goal.achieved
                    ? 'Meta alcançada'
                    : '${Money(goal.savedCents, currency).format()} de ${Money(goal.goal.targetCents, currency).format()}',
                maxLines: 2,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
