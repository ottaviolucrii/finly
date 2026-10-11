import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/dashboard/presentation/widgets/home/home_band.dart';
import 'package:flutter/material.dart';

/// The picture of a credit card: deep blue, the Finly shield, a gold chip,
/// the name, its days and its limit.
class CardArt extends StatelessWidget {
  final CreditCardEntity card;

  /// Opens the card; null when the picture is not tappable.
  final VoidCallback? onTap;

  const CardArt({super.key, required this.card, this.onTap});

  /// Width over height, like a real card.
  static const aspectRatio = 1.75;

  @override
  Widget build(BuildContext context) {
    final days = 'Fecha dia ${card.closingDay} · vence dia ${card.dueDay}';

    return Semantics(
      button: onTap != null,
      label: 'Cartão ${card.name}. $days. Limite ${card.limit.format()}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: AppColors.deepBlue,
        elevation: 8,
        shadowColor: AppColors.deepBlue.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.asset(
                          finlyMarkAsset,
                          width: 32,
                          height: 32,
                          errorBuilder: (context, error, stackTrace) => const SizedBox(
                            width: 32,
                            height: 32,
                            child: ColoredBox(color: AppColors.white),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text('Crédito', style: TextStyle(fontSize: 13, color: AppColors.onBand)),
                    ],
                  ),
                  // The chip takes the space left, so the card never overflows
                  // on a small screen or with bigger system text.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 40,
                        height: 30,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              card.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: AppColors.white,
                              ),
                            ),
                            Text(
                              days,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: AppColors.onBand),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 2,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.bottomRight,
                          child: Text(
                            'Limite ${card.limit.format()}',
                            maxLines: 1,
                            style: const TextStyle(fontSize: 13, color: AppColors.onBand),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
