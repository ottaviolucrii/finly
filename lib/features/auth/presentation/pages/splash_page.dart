import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/widgets/finly_logo.dart';
import 'package:flutter/material.dart';

/// Shown while the stored session is being restored: the finished logo, the
/// same as the end of the opening animation, so going from one to the other
/// shows no jump.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(size: Size(176, 190), painter: FinlyLogoPainter.done),
            SizedBox(height: 22),
            Text(
              'FINLY',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 34,
                letterSpacing: 3,
                color: AppColors.midnight,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'INTELIGÊNCIA FINANCEIRA',
              style: TextStyle(fontSize: 12, letterSpacing: 2, color: AppColors.textMuted),
            ),
            SizedBox(height: 28),
            SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      ),
    );
  }
}
