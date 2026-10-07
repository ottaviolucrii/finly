import 'package:finly/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Drawn over the app when it leaves the screen, so the app switcher shows a
/// dark Finly card and no balances (SRS FR-A07).
class PrivacyCover extends StatelessWidget {
  const PrivacyCover({super.key});

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: AppColors.midnight,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 48, color: AppColors.white),
            SizedBox(height: 12),
            Text(
              'Finly',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}