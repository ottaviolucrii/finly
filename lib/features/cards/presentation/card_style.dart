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

const List<String> _monthNamesLower = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

/// "Fatura de outubro"; the year is added when it is not the year of [today]
/// ("Fatura de dezembro de 2025").
String invoiceTitle(InvoiceEntity invoice, DateTime today) {
  final month = invoice.referenceMonth;
  final name = _monthNamesLower[month.month - 1];
  return month.year == today.year ? 'Fatura de $name' : 'Fatura de $name de ${month.year}';
}

/// "Outubro" for a row of the list; the year is added when it is not the
/// year of [today] ("Dezembro de 2025").
String invoiceMonthLabel(InvoiceEntity invoice, DateTime today) {
  final month = invoice.referenceMonth;
  final name = _monthNamesLower[month.month - 1];
  final capital = '${name[0].toUpperCase()}${name.substring(1)}';
  return month.year == today.year ? capital : '$capital de ${month.year}';
}

/// The invoice to show first on a card: a closed one still to pay (the one
/// due first), otherwise the open one that closes first (the current one),
/// otherwise none.
InvoiceEntity? currentInvoice(List<InvoiceEntity> invoices, DateTime today) {
  InvoiceEntity? toPay;
  for (final invoice in invoices) {
    if (invoice.statusOn(today) == InvoiceStatus.closed && invoice.needsPayment) {
      if (toPay == null || invoice.dueDate.isBefore(toPay.dueDate)) toPay = invoice;
    }
  }
  if (toPay != null) return toPay;
  // Several invoices can be open at once (installments create the next ones
  // ahead of time): the current one is the one that closes first.
  InvoiceEntity? current;
  for (final invoice in invoices) {
    if (invoice.statusOn(today) != InvoiceStatus.open) continue;
    if (current == null || invoice.periodEnd.isBefore(current.periodEnd)) current = invoice;
  }
  return current;
}

/// How an invoice tag looks: blue while open, gold when it has to be paid
/// (closed, or paid in part), green when paid.
enum InvoiceTone { open, toPay, paid }

InvoiceTone invoiceTone(InvoiceEntity invoice, DateTime today) {
  if (invoice.isPaid) return InvoiceTone.paid;
  if (invoice.isPartiallyPaid) return InvoiceTone.toPay;
  return invoice.statusOn(today) == InvoiceStatus.open ? InvoiceTone.open : InvoiceTone.toPay;
}

/// Which card to show first when the person came to pay: the one with a
/// closed invoice still to pay that is due first; otherwise the first card.
/// [invoicesByCard] has the invoices of each card by its account id (a card
/// whose invoices did not load is simply not considered).
int cardIndexToPay(
  List<CreditCardEntity> cards,
  Map<String, List<InvoiceEntity>> invoicesByCard,
  DateTime today,
) {
  var best = 0;
  DateTime? bestDue;
  for (var i = 0; i < cards.length; i++) {
    final invoice = currentInvoice(invoicesByCard[cards[i].accountId] ?? const [], today);
    if (invoice == null || !invoice.needsPayment) continue;
    if (invoice.statusOn(today) != InvoiceStatus.closed && !invoice.isPartiallyPaid) continue;
    if (bestDue == null || invoice.dueDate.isBefore(bestDue)) {
      best = i;
      bestDue = invoice.dueDate;
    }
  }
  return best;
}
