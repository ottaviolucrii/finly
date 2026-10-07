import 'dart:math' as math;

import 'package:finly/core/money/money.dart';
import 'package:finly/features/forecast/domain/entities/forecast_items.dart';
import 'package:flutter/material.dart';

/// "12,3 mil", "-1,5 mi", "850": an amount in whole reais, short enough for an
/// axis. It is only for drawing: no money is ever added up with it.
String compactAmount(int cents) {
  final reais = (cents / 100).round();
  final absolute = reais.abs();
  final sign = reais < 0 ? '-' : '';

  String one(double value) => value.toStringAsFixed(1).replaceAll('.', ',');

  if (absolute >= 1000000) return '$sign${one(absolute / 1000000)} mi';
  if (absolute >= 1000) return '$sign${one(absolute / 1000)} mil';
  return '$sign$absolute';
}

/// "05/10".
String shortDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month';
}

/// Where the points go on the chart: the vertical range of the data with some
/// room above and below, and how far along the line each day is.
class ForecastChartScale {
  final int minCents;
  final int maxCents;
  final int count;

  const ForecastChartScale({
    required this.minCents,
    required this.maxCents,
    required this.count,
  });

  factory ForecastChartScale.of(List<ForecastPoint> points) {
    var low = points.first.balanceCents;
    var high = low;
    for (final point in points) {
      low = math.min(low, point.balanceCents);
      high = math.max(high, point.balanceCents);
    }

    // A flat line still needs a range to be drawn in.
    final spread = high - low;
    final pad = spread == 0
        ? math.max(100, (low.abs() * 0.05).round())
        : (spread * 0.1).round();

    return ForecastChartScale(
      minCents: low - pad,
      maxCents: high + pad,
      count: points.length,
    );
  }

  /// 0 for the first day, 1 for the last.
  double xFraction(int index) => count <= 1 ? 0 : index / (count - 1);

  /// 0 at the bottom, 1 at the top.
  double yFraction(int cents) => (cents - minCents) / (maxCents - minCents);

  /// Whether zero is inside the drawn range, so the line of zero is shown.
  bool get showsZero => minCents < 0 && maxCents > 0;
}

/// The projected balance as a line: blue while the balance is above zero, red
/// where it is below, a marker on the lowest day.
class ForecastLineChart extends StatelessWidget {
  final List<ForecastPoint> points;
  final String currency;
  final double height;

  const ForecastLineChart({
    super.key,
    required this.points,
    required this.currency,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.bodySmall;
    final lowest = _lowest();

    return Semantics(
      label: 'Gráfico da previsão de saldo. Começa em '
          '${Money(points.first.balanceCents, currency).format()} e termina em '
          '${Money(points.last.balanceCents, currency).format()}. O menor saldo é '
          '${Money(lowest.balanceCents, currency).format()} em ${shortDate(lowest.date)}.',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: ForecastChartPainter(
              points: points,
              lineColor: scheme.primary,
              negativeColor: scheme.error,
              markerColor: scheme.secondary,
              gridColor: scheme.outlineVariant,
              textStyle: (text ?? const TextStyle(fontSize: 11)).copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  ForecastPoint _lowest() {
    var best = points.first;
    for (final point in points) {
      if (point.balanceCents < best.balanceCents) best = point;
    }
    return best;
  }
}

class ForecastChartPainter extends CustomPainter {
  final List<ForecastPoint> points;
  final Color lineColor;
  final Color negativeColor;
  final Color markerColor;
  final Color gridColor;
  final TextStyle textStyle;

  const ForecastChartPainter({
    required this.points,
    required this.lineColor,
    required this.negativeColor,
    required this.markerColor,
    required this.gridColor,
    required this.textStyle,
  });

  static const double _left = 52;
  static const double _right = 8;
  static const double _top = 8;
  static const double _bottom = 22;

  void _label(Canvas canvas, String text, Offset at, {bool alignRight = false, bool center = false}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    var dx = at.dx;
    if (alignRight) dx -= painter.width;
    if (center) dx -= painter.width / 2;
    painter.paint(canvas, Offset(dx, at.dy - painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final plot = Rect.fromLTRB(_left, _top, size.width - _right, size.height - _bottom);
    if (plot.width <= 0 || plot.height <= 0) return;

    final scale = ForecastChartScale.of(points);
    double x(int i) => plot.left + plot.width * scale.xFraction(i);
    double y(int cents) => plot.bottom - plot.height * scale.yFraction(cents);

    // Three guide lines with their values.
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final cents = scale.minCents + ((scale.maxCents - scale.minCents) * (i / 2)).round();
      final dy = y(cents);
      canvas.drawLine(Offset(plot.left, dy), Offset(plot.right, dy), grid);
      _label(canvas, compactAmount(cents), Offset(plot.left - 6, dy), alignRight: true);
    }

    // The line of zero, when the balance goes there.
    if (scale.showsZero) {
      final zero = Paint()
        ..color = negativeColor.withValues(alpha: 0.6)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(plot.left, y(0)), Offset(plot.right, y(0)), zero);
    }

    // The balance, one segment per day; red where it is below zero.
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i].balanceCents;
      final b = points[i + 1].balanceCents;
      final paint = Paint()
        ..color = (a < 0 || b < 0) ? negativeColor : lineColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(x(i), y(a)), Offset(x(i + 1), y(b)), paint);
    }

    // The lowest day.
    var lowestIndex = 0;
    for (var i = 0; i < points.length; i++) {
      if (points[i].balanceCents < points[lowestIndex].balanceCents) lowestIndex = i;
    }
    final marker = Offset(x(lowestIndex), y(points[lowestIndex].balanceCents));
    canvas.drawCircle(marker, 6, Paint()..color = markerColor);
    canvas.drawCircle(
      marker,
      6,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Three dates under the chart.
    final middle = (points.length - 1) ~/ 2;
    final labelY = size.height - _bottom / 2 + 2;
    _label(canvas, shortDate(points.first.date), Offset(plot.left, labelY));
    _label(canvas, shortDate(points[middle].date), Offset(x(middle), labelY), center: true);
    _label(canvas, shortDate(points.last.date), Offset(plot.right, labelY), alignRight: true);
  }

  @override
  bool shouldRepaint(ForecastChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.negativeColor != negativeColor ||
        oldDelegate.markerColor != markerColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textStyle != textStyle;
  }
}
