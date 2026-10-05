import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/presentation/card_style.dart';
import 'package:flutter/material.dart';

/// The limit bar of a card: used, available, and a text warning from 80%.
class CardUsageSummary extends StatelessWidget {
  final CreditCardEntity card;

  const CardUsageSummary({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final level = cardUsageLevel(card);
    final color = cardUsageColor(context, level);
    final label = cardUsageLabel(level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: card.usageRatio.clamp(0.0, 1.0).toDouble(),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          color: color,
          backgroundColor: scheme.onSurface.withValues(alpha: 0.12),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Usado ${card.used.format()}', style: text.bodyMedium),
            Text('Disponível ${card.available.format()}', style: text.bodyMedium),
          ],
        ),
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              label,
              style: text.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}