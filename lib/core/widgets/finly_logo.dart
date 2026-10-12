import 'package:finly/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// The Finly shield as vector shapes (the gold part and the two blue arrows),
/// in a 840 × 960 box, so each part can be drawn and animated on its own.
abstract final class FinlyLogoShapes {
  static const size = Size(840, 960);
  static const _dx = -200.0;
  static const _dy = -120.0;

  static Path gold() => Path()
    ..moveTo(855 + _dx, 425 + _dy)
    ..lineTo(995 + _dx, 343 + _dy)
    ..lineTo(995 + _dx, 650 + _dy)
    ..quadraticBezierTo(990 + _dx, 870 + _dy, 625 + _dx, 1055 + _dy)
    ..lineTo(448 + _dx, 935 + _dy)
    ..lineTo(428 + _dx, 745 + _dy)
    ..quadraticBezierTo(520 + _dx, 830 + _dy, 625 + _dx, 890 + _dy)
    ..quadraticBezierTo(855 + _dx, 760 + _dy, 855 + _dx, 650 + _dy)
    ..close();

  static Path upperArrow() => Path()
    ..moveTo(260 + _dx, 307 + _dy)
    ..quadraticBezierTo(480 + _dx, 215 + _dy, 735 + _dx, 233 + _dy)
    ..lineTo(735 + _dx, 145 + _dy)
    ..lineTo(985 + _dx, 307 + _dy)
    ..lineTo(735 + _dx, 450 + _dy)
    ..lineTo(735 + _dx, 357 + _dy)
    ..quadraticBezierTo(560 + _dx, 342 + _dy, 400 + _dx, 390 + _dy)
    ..lineTo(400 + _dx, 510 + _dy)
    ..quadraticBezierTo(320 + _dx, 540 + _dy, 260 + _dx, 590 + _dy)
    ..close();

  static Path lowerArrow() => Path()
    ..moveTo(560 + _dx, 435 + _dy)
    ..lineTo(808 + _dx, 590 + _dy)
    ..lineTo(560 + _dx, 742 + _dy)
    ..lineTo(560 + _dx, 652 + _dy)
    ..quadraticBezierTo(430 + _dx, 652 + _dy, 405 + _dx, 690 + _dy)
    ..quadraticBezierTo(395 + _dx, 800 + _dy, 405 + _dx, 900 + _dy)
    ..quadraticBezierTo(260 + _dx, 790 + _dy, 262 + _dx, 690 + _dy)
    ..quadraticBezierTo(262 + _dx, 560 + _dy, 560 + _dx, 530 + _dy)
    ..close();

  // Built and measured once: the animation draws them every frame.
  static final goldPath = gold();
  static final upperPath = upperArrow();
  static final lowerPath = lowerArrow();
  static final goldOutline = goldPath.computeMetrics().toList();
  static final upperOutline = upperPath.computeMetrics().toList();
  static final lowerOutline = lowerPath.computeMetrics().toList();
}

/// Draws the shield. Each part is first traced as a line ([upper], [lower],
/// [goldLine]: 0 to 1, how much of it is drawn) and then filled ([fill]: 0 to
/// 1). With everything at 1 it is the finished logo.
class FinlyLogoPainter extends CustomPainter {
  final double upper;
  final double lower;
  final double goldLine;
  final double fill;
  final Color arrowColor;
  final Color goldColor;

  const FinlyLogoPainter({
    this.upper = 1,
    this.lower = 1,
    this.goldLine = 1,
    this.fill = 1,
    this.arrowColor = const Color(0xFF0B54D6),
    this.goldColor = AppColors.gold,
  });

  /// The finished logo.
  static const done = FinlyLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / FinlyLogoShapes.size.height;
    final width = FinlyLogoShapes.size.width * scale;
    canvas.save();
    canvas.translate((size.width - width) / 2, (size.height - FinlyLogoShapes.size.height * scale) / 2);
    canvas.scale(scale);

    void part(Path path, Iterable<Path> Function(double drawn) traced, double drawn, Color color) {
      if (drawn <= 0 && fill <= 0) return;
      if (fill > 0) {
        canvas.drawPath(path, Paint()..color = color.withValues(alpha: fill.clamp(0.0, 1.0)));
      }
      if (drawn > 0 && fill < 1) {
        final line = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round;
        for (final piece in traced(drawn.clamp(0.0, 1.0))) {
          canvas.drawPath(piece, line);
        }
      }
    }

    part(
      FinlyLogoShapes.goldPath,
      (d) => [for (final m in FinlyLogoShapes.goldOutline) m.extractPath(0, m.length * d)],
      goldLine,
      goldColor,
    );
    part(
      FinlyLogoShapes.upperPath,
      (d) => [for (final m in FinlyLogoShapes.upperOutline) m.extractPath(0, m.length * d)],
      upper,
      arrowColor,
    );
    part(
      FinlyLogoShapes.lowerPath,
      (d) => [for (final m in FinlyLogoShapes.lowerOutline) m.extractPath(0, m.length * d)],
      lower,
      arrowColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(FinlyLogoPainter oldDelegate) =>
      oldDelegate.upper != upper ||
      oldDelegate.lower != lower ||
      oldDelegate.goldLine != goldLine ||
      oldDelegate.fill != fill ||
      oldDelegate.arrowColor != arrowColor;
}
