import 'package:finly/core/money/money.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/presentation/card_style.dart';
import 'package:flutter/material.dart';

/// The limit of a card: what is in use, what is free, a bar, and a text
/// warning from 80% (so colour is never the only signal).
class CardUsageSummary extends StatelessWidget {
  final CreditCardEntity card;

  const CardUsageSummary({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final level = cardUsageLevel(card);
    final label = cardUsageLabel(level);
    final color = switch (level) {
      CardUsageLevel.normal => AppColors.gold,
      CardUsageLevel.warning => dark ? AppColors.gold : AppColors.warning,
      CardUsageLevel.over => scheme.error,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Em uso ${card.used.format()}',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Text(
              'Livre ${card.isOverLimit ? Money(0, card.currency).format() : card.available.format()}',
              style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: card.usageRatio.clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            color: color,
            backgroundColor: dark ? AppColors.borderDark : AppColors.track,
          ),
        ),
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              label,
              style: text.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}
