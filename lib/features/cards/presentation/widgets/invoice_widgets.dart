import 'package:finly/core/money/money.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/presentation/card_style.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/presentation/transaction_style.dart';
import 'package:flutter/material.dart';

/// "17/10" for the small tiles of an invoice.
String dayMonth(DateTime date) => formatDateBr(date).substring(0, 5);

/// The tag of an invoice: "Aberta", "Fechada", "Parcialmente paga" or "Paga",
/// in blue, gold or green.
class InvoiceStatusChip extends StatelessWidget {
  final InvoiceEntity invoice;
  final DateTime today;

  const InvoiceStatusChip({super.key, required this.invoice, required this.today});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (Color background, Color foreground) = switch (invoiceTone(invoice, today)) {
      InvoiceTone.open => dark
          ? (AppColors.blueTintDark, AppColors.techBlueOnDark)
          : (AppColors.blueTint, const Color(0xFF0B4BB3)),
      InvoiceTone.toPay => dark
          ? (AppColors.gold.withValues(alpha: 0.18), AppColors.goldOnBand)
          : (AppColors.goldTint, AppColors.goldOnLight),
      InvoiceTone.paid => dark
          ? (AppColors.positive.withValues(alpha: 0.25), const Color(0xFF6FD39B))
          : (AppColors.positiveTint, AppColors.positive),
    };

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      alignment: Alignment.center,
      child: Text(
        invoiceDisplayLabel(invoice, today),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: foreground),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;

  const _Tile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: dark ? AppColors.canvasDark : AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// The invoice that matters now, as a card: its title and tag, the total,
/// when it closes, when it is due, what was paid, what is still owed, and the
/// buttons to pay it and to see it.
class InvoiceSummaryCard extends StatelessWidget {
  final InvoiceEntity invoice;
  final String currency;
  final DateTime today;

  /// Pays it; null hides the button (nothing to pay).
  final VoidCallback? onPay;

  /// Opens the invoice with its purchases; null hides the button (already
  /// there).
  final VoidCallback? onOpen;

  /// The card name, shown small above the total (on the invoice screen).
  final String? cardName;

  /// True while a payment is being sent.
  final bool paying;

  const InvoiceSummaryCard({
    super.key,
    required this.invoice,
    required this.currency,
    required this.today,
    this.onPay,
    this.onOpen,
    this.cardName,
    this.paying = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    String money(int cents) => Money(cents, currency).format();
    final canPay = invoice.needsPayment && onPay != null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    container: true,
                    header: true,
                    child: Text(
                      invoiceTitle(invoice, today),
                      style: text.titleLarge?.copyWith(fontSize: 17),
                    ),
                  ),
                ),
                InvoiceStatusChip(invoice: invoice, today: today),
              ],
            ),
            if (cardName != null) ...[
              const SizedBox(height: 2),
              Text(cardName!, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 10),
            Text(
              money(invoice.totalCents),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 30,
                letterSpacing: -0.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            if (invoice.isPartiallyPaid)
              Text(
                'Falta ${money(invoice.remainingCents)}',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.goldOnBand : AppColors.goldOnLight,
                ),
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _Tile(label: 'Fecha', value: dayMonth(invoice.periodEnd))),
                const SizedBox(width: 8),
                Expanded(child: _Tile(label: 'Vence', value: dayMonth(invoice.dueDate))),
                const SizedBox(width: 8),
                Expanded(child: _Tile(label: 'Pago', value: money(invoice.paidCents))),
              ],
            ),
            if (canPay || onOpen != null) ...[
              const SizedBox(height: 16),
              if (paying)
                const LinearProgressIndicator()
              else
                Row(
                  children: [
                    if (canPay)
                      Expanded(
                        child: FilledButton(
                          onPressed: onPay,
                          child: Text(invoice.isPartiallyPaid ? 'Pagar o restante' : 'Pagar fatura'),
                        ),
                      ),
                    if (canPay && onOpen != null) const SizedBox(width: 10),
                    if (onOpen != null)
                      canPay
                          ? OutlinedButton(
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                              onPressed: onOpen,
                              child: const Text('Ver compras'),
                            )
                          : Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                                onPressed: onOpen,
                                child: const Text('Ver compras'),
                              ),
                            ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One invoice in a list: the month, when it is due, the total, its tag and,
/// when paid in part, what is still owed.
class InvoiceRow extends StatelessWidget {
  final InvoiceEntity invoice;
  final String currency;
  final DateTime today;
  final VoidCallback onTap;

  const InvoiceRow({
    super.key,
    required this.invoice,
    required this.currency,
    required this.today,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final when = invoice.isPaid ? 'Venceu em ${formatDateBr(invoice.dueDate)}' : 'Vence em ${formatDateBr(invoice.dueDate)}';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoiceMonthLabel(invoice, today),
                    style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(when, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Money(invoice.totalCents, currency).format(),
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                InvoiceStatusChip(invoice: invoice, today: today),
                if (invoice.isPartiallyPaid)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Falta ${Money(invoice.remainingCents, currency).format()}',
                      style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// One purchase of an invoice: the day, the description and the amount.
class PurchaseRow extends StatelessWidget {
  final TransactionEntity transaction;

  const PurchaseRow({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final date = formatDateBr(transaction.occurredAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  transaction.isPending ? '$date · Pendente' : date,
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            transactionAmountText(transaction),
            style: text.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: transaction.type.isCredit
                  ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF6FD39B) : AppColors.positive)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
