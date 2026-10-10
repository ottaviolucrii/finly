import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_status.dart';
import 'package:flutter/material.dart';

enum CardUsageLevel { normal, warning, over }

/// 80% of the limit and above is a warning; above 100% is over the limit
/// (SRS FR-K06).
CardUsageLevel cardUsageLevel(CreditCardEntity card) {
  if (card.isOverLimit) return CardUsageLevel.over;
  if (card.usageRatio >= 0.8) return CardUsageLevel.warning;
  return CardUsageLevel.normal;
}

/// Text that goes with the colour, so colour is never the only signal.
String? cardUsageLabel(CardUsageLevel level) => switch (level) {
      CardUsageLevel.normal => null,
      CardUsageLevel.warning => 'Perto do limite',
      CardUsageLevel.over => 'Acima do limite',
    };

Color cardUsageColor(BuildContext context, CardUsageLevel level) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  return switch (level) {
    CardUsageLevel.normal => theme.colorScheme.primary,
    // The brand gold reads well on dark; the darker orange reads well on light.
    CardUsageLevel.warning => dark ? AppColors.gold : AppColors.warning,
    CardUsageLevel.over => theme.colorScheme.error,
  };
}

String invoiceStatusLabel(InvoiceStatus status) => switch (status) {
      InvoiceStatus.open => 'Aberta',
      InvoiceStatus.closed => 'Fechada',
      InvoiceStatus.paid => 'Paga',
    };

IconData invoiceStatusIcon(InvoiceStatus status) => switch (status) {
      InvoiceStatus.open => Icons.schedule,
      InvoiceStatus.closed => Icons.lock_outline,
      InvoiceStatus.paid => Icons.check_circle_outline,
    };

/// The label of an invoice on [today]: "Parcialmente paga" when part of it was
/// paid and some is still owed, otherwise the label of its status.
String invoiceDisplayLabel(InvoiceEntity invoice, DateTime today) {
  if (invoice.isPartiallyPaid) return 'Parcialmente paga';
  return invoiceStatusLabel(invoice.statusOn(today));
}

IconData invoiceDisplayIcon(InvoiceEntity invoice, DateTime today) {
  if (invoice.isPartiallyPaid) return Icons.timelapse;
  return invoiceStatusIcon(invoice.statusOn(today));
}
