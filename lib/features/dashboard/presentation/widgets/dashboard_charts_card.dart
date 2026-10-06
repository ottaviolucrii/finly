import 'dart:math' as math;

import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:finly/features/dashboard/domain/entities/dashboard_charts.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_charts_cubit.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_charts_state.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const List<String> _monthNames = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

String _shortMonth(DateTime month) => _monthNames[month.month - 1];

/// The two dashboard charts: income and expenses of the last months, and this
/// month's spending by category. It reloads whenever the dashboard does.
class DashboardChartsCard extends StatelessWidget {
  final WorkspaceEntity workspace;

  const DashboardChartsCard({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardChartsCubit>(
      key: ValueKey(workspace.id),
      create: (_) => sl<DashboardChartsCubit>()..load(workspace.id),
      child: BlocListener<DashboardCubit, DashboardState>(
        listenWhen: (previous, current) =>
            previous.status != current.status &&
            current.status == DashboardStatus.loaded,
        listener: (context, _) => context.read<DashboardChartsCubit>().reload(),
        child: const _ChartsBody(),
      ),
    );
  }
}

class _ChartsBody extends StatefulWidget {
  const _ChartsBody();

  @override
  State<_ChartsBody> createState() => _ChartsBodyState();
}

class _ChartsBodyState extends State<_ChartsBody> {
  String? _currency;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardChartsCubit, DashboardChartsState>(
      builder: (context, state) {
        final charts = state.charts;

        if (charts == null) {
          if (state.status == DashboardChartsStatus.failure) {
            return _MessageCard(
              message: 'Não foi possível carregar os gráficos.',
              onRetry: () => context.read<DashboardChartsCubit>().reload(),
            );
          }
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (charts.isEmpty) {
          return const _MessageCard(
            message: 'Os gráficos aparecem quando houver lançamentos.',
          );
        }

        // No firstWhere(orElse): a plain loop, to stay safe with model types.
        var selected = charts.byCurrency.first;
        for (final item in charts.byCurrency) {
          if (item.currency == _currency) selected = item;
        }

        final text = Theme.of(context).textTheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (charts.byCurrency.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final item in charts.byCurrency)
                      ChoiceChip(
                        label: Text(item.currency),
                        selected: item.currency == selected.currency,
                        onSelected: (_) =>
                            setState(() => _currency = item.currency),
                      ),
                  ],
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Entradas e saídas', style: text.titleMedium),
                    Text(
                      'Últimos 6 meses · só o que já aconteceu',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    if (selected.hasFlow)
                      MonthlyBarChart(
                        key: ValueKey('bars-${selected.currency}'),
                        points: selected.months,
                        currency: selected.currency,
                      )
                    else
                      Text(
                        'Nenhuma movimentação nos últimos 6 meses.',
                        style: text.bodyMedium,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gastos por categoria · ${_shortMonth(charts.month)} ${charts.month.year}',
                      style: text.titleMedium,
                    ),
                    Text('Inclui lançamentos pendentes', style: text.bodySmall),
                    const SizedBox(height: 12),
                    if (selected.categories.isEmpty)
                      Text('Nenhum gasto neste mês.', style: text.bodyMedium)
                    else
                      CategoryDonutChart(
                        slices: selected.categories,
                        currency: selected.currency,
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _MessageCard({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Tentar de novo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Income (Tech Blue) and expense (Gold) bars, one group per month. Tap or
/// drag over a month to see its values below the chart.
class MonthlyBarChart extends StatefulWidget {
  final List<MonthlyFlowPoint> points;
  final String currency;

  const MonthlyBarChart({
    super.key,
    required this.points,
    required this.currency,
  });

  @override
  State<MonthlyBarChart> createState() => _MonthlyBarChartState();
}

class _MonthlyBarChartState extends State<MonthlyBarChart> {
  late int _selected = widget.points.isEmpty ? 0 : widget.points.length - 1;

  void _select(double dx, double width) {
    final count = widget.points.length;
    if (count == 0 || width <= 0) return;
    final index = (dx / width * count).floor().clamp(0, count - 1);
    if (index != _selected) setState(() => _selected = index);
  }

  String _money(int cents) => Money(cents, widget.currency).format();

  String get _summary => widget.points
      .map(
        (p) => '${_shortMonth(p.month)}: entradas ${_money(p.incomeCents)}, '
            'saídas ${_money(p.expenseCents)}',
      )
      .join('; ');

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final income = scheme.primary;
    final expense = scheme.secondary;
    final point = widget.points[_selected];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          label: 'Entradas e saídas por mês. $_summary',
          child: ExcludeSemantics(
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                key: const Key('monthly-bars'),
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _select(d.localPosition.dx, constraints.maxWidth),
                onHorizontalDragUpdate: (d) =>
                    _select(d.localPosition.dx, constraints.maxWidth),
                child: SizedBox(
                  height: 168,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _BarsPainter(
                      points: widget.points,
                      selected: _selected,
                      incomeColor: income,
                      expenseColor: expense,
                      axisColor: scheme.outline,
                      highlightColor: scheme.onSurface.withValues(alpha: 0.06),
                      labelStyle: (text.bodySmall ?? const TextStyle()).copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('${_shortMonth(point.month)} ${point.month.year}', style: text.titleSmall),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _LegendValue(
              color: income,
              label: 'Entradas',
              value: '+ ${_money(point.incomeCents)}',
            ),
            _LegendValue(
              color: expense,
              label: 'Saídas',
              value: '- ${_money(point.expenseCents)}',
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendValue extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendValue({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text('$label ', style: text.bodySmall),
        Text(value, style: text.titleSmall),
      ],
    );
  }
}

class _BarsPainter extends CustomPainter {
  final List<MonthlyFlowPoint> points;
  final int selected;
  final Color incomeColor;
  final Color expenseColor;
  final Color axisColor;
  final Color highlightColor;
  final TextStyle labelStyle;

  const _BarsPainter({
    required this.points,
    required this.selected,
    required this.incomeColor,
    required this.expenseColor,
    required this.axisColor,
    required this.highlightColor,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = points.length;
    if (count == 0) return;

    const labelHeight = 22.0;
    const topPadding = 8.0;
    final chartHeight = size.height - labelHeight - topPadding;
    final baseline = topPadding + chartHeight;

    var maxValue = 1;
    for (final point in points) {
      maxValue = math.max(maxValue, math.max(point.incomeCents, point.expenseCents));
    }

    final groupWidth = size.width / count;
    final barWidth = math.min(groupWidth * 0.3, 18.0);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(selected * groupWidth + 2, 0, groupWidth - 4, size.height),
        const Radius.circular(8),
      ),
      Paint()..color = highlightColor,
    );

    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1,
    );

    void bar(double left, int cents, Color color) {
      if (cents <= 0) return;
      final height = math.max(chartHeight * cents / maxValue, 2.0);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(left, baseline - height, barWidth, height),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        Paint()..color = color,
      );
    }

    for (var i = 0; i < count; i++) {
      final point = points[i];
      final centerX = i * groupWidth + groupWidth / 2;
      bar(centerX - barWidth - 1, point.incomeCents, incomeColor);
      bar(centerX + 1, point.expenseCents, expenseColor);

      final label = TextPainter(
        text: TextSpan(
          text: _shortMonth(point.month),
          style: i == selected
              ? labelStyle.copyWith(fontWeight: FontWeight.w700)
              : labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(centerX - label.width / 2, baseline + 4));
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.points != points ||
      old.selected != selected ||
      old.incomeColor != incomeColor ||
      old.expenseColor != expenseColor ||
      old.axisColor != axisColor ||
      old.highlightColor != highlightColor ||
      old.labelStyle != labelStyle;
}

/// A donut of this month's spending, with a legend that also gives each
/// category's value and share (colour is never the only cue).
class CategoryDonutChart extends StatelessWidget {
  final List<CategorySlice> slices;
  final String currency;

  const CategoryDonutChart({
    super.key,
    required this.slices,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final total = slices.fold<int>(0, (sum, slice) => sum + slice.spentCents);
    if (total <= 0) return const SizedBox.shrink();

    int percent(CategorySlice slice) => (slice.spentCents * 100 / total).round();

    final summary = slices
        .map((slice) => '${slice.name} ${percent(slice)}%')
        .join(', ');

    return Column(
      children: [
        Semantics(
          container: true,
          label: 'Gastos por categoria: $summary',
          child: ExcludeSemantics(
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size.square(140),
                    painter: _DonutPainter(
                      values: [for (final s in slices) s.spentCents.toDouble()],
                      colors: [for (final s in slices) categoryColor(s.colorHex)],
                      trackColor: scheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                  SizedBox(
                    width: 92,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Total', style: text.bodySmall),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            Money(total, currency).format(),
                            style: text.titleSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final slice in slices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: categoryColor(slice.colorHex),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    slice.name,
                    style: text.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(Money(slice.spentCents, currency).format(), style: text.titleSmall),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${percent(slice)}%',
                    style: text.bodySmall,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color trackColor;

  const _DonutPainter({
    required this.values,
    required this.colors,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);

    Paint ring(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    canvas.drawArc(rect, 0, 2 * math.pi, false, ring(trackColor));

    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return;

    final gap = values.length > 1 ? 0.03 : 0.0;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      final drawn = math.max(sweep - gap, 0.01);
      canvas.drawArc(rect, start + gap / 2, drawn, false, ring(colors[i]));
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.values != values || old.colors != colors || old.trackColor != trackColor;
}