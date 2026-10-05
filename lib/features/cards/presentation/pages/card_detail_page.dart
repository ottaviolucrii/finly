import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/presentation/card_messages.dart';
import 'package:finly/features/cards/presentation/card_style.dart';
import 'package:finly/features/cards/presentation/cubit/invoices_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/invoices_state.dart';
import 'package:finly/features/cards/presentation/pages/installment_form_page.dart';
import 'package:finly/features/cards/presentation/pages/invoice_detail_page.dart';
import 'package:finly/features/cards/presentation/widgets/card_usage_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// One card: its limit, installment purchases and its invoices.
class CardDetailPage extends StatelessWidget {
  final WorkspaceEntity workspace;
  final CreditCardEntity card;

  const CardDetailPage({super.key, required this.workspace, required this.card});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<InvoicesCubit>()..load(card),
      child: _CardDetailView(workspace: workspace, card: card),
    );
  }
}

class _CardDetailView extends StatelessWidget {
  final WorkspaceEntity workspace;
  final CreditCardEntity card;

  const _CardDetailView({required this.workspace, required this.card});

  Future<void> _openInstallments(
    BuildContext context,
    CreditCardEntity current,
  ) async {
    final cubit = context.read<InvoicesCubit>();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => InstallmentFormPage(card: current),
      ),
    );
    if (created == true) await cubit.reload();
  }

  Future<void> _openInvoice(
    BuildContext context,
    CreditCardEntity current,
    InvoiceEntity invoice,
  ) async {
    final cubit = context.read<InvoicesCubit>();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => InvoiceDetailPage(
          workspace: workspace,
          card: current,
          invoice: invoice,
        ),
      ),
    );
    // Paying changes the invoice and the used limit.
    await cubit.reload();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isBusiness = workspace.type == WorkspaceType.business;

    return Scaffold(
      appBar: AppBar(
        title: Text(card.name),
        backgroundColor: isBusiness ? AppColors.deepBlue : null,
        foregroundColor: isBusiness ? AppColors.white : null,
      ),
      body: BlocBuilder<InvoicesCubit, InvoicesState>(
        builder: (context, state) {
          final current = state.card ?? card;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fecha dia ${current.closingDay} · vence dia ${current.dueDay}',
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      CardUsageSummary(card: current),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.splitscreen),
                  label: const Text('Compra parcelada'),
                  onPressed: () => _openInstallments(context, current),
                ),
              ),
              const SizedBox(height: 16),
              Text('Faturas', style: text.titleMedium),
              const SizedBox(height: 8),
              ..._invoices(context, state, current),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _invoices(
    BuildContext context,
    InvoicesState state,
    CreditCardEntity current,
  ) {
    final text = Theme.of(context).textTheme;

    if (state.status == InvoicesStatus.failure) {
      return [
        Text(cardFailureMessage(state.failure!)),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => context.read<InvoicesCubit>().reload(),
          child: const Text('Tentar de novo'),
        ),
      ];
    }
    if (state.status != InvoicesStatus.loaded && state.invoices.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (state.invoices.isEmpty) {
      return [
        Text(
          'Nenhuma fatura ainda. A primeira aparece quando você lança uma '
          'compra neste cartão.',
          style: text.bodyMedium,
        ),
      ];
    }

    final today = DateTime.now();
    return [
      for (final invoice in state.invoices)
        _InvoiceTile(
          invoice: invoice,
          currency: current.currency,
          today: today,
          onTap: () => _openInvoice(context, current, invoice),
        ),
    ];
  }
}

class _InvoiceTile extends StatelessWidget {
  final InvoiceEntity invoice;
  final String currency;
  final DateTime today;
  final VoidCallback onTap;

  const _InvoiceTile({
    required this.invoice,
    required this.currency,
    required this.today,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final status = invoice.statusOn(today);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthYearLabel(invoice.referenceMonth),
                      style: text.titleMedium,
                    ),
                    Text(
                      'Vence ${formatDateBr(invoice.dueDate)}',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Money(invoice.totalCents, currency).format(),
                    style: text.titleMedium,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(invoiceStatusIcon(status), size: 14),
                      const SizedBox(width: 4),
                      Text(invoiceStatusLabel(status), style: text.bodySmall),
                    ],
                  ),
                ],
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}