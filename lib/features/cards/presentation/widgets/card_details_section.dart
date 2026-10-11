import 'package:finly/core/di/injection.dart';
import 'package:finly/core/widgets/grouped_list.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/presentation/card_messages.dart';
import 'package:finly/features/cards/presentation/card_style.dart';
import 'package:finly/features/cards/presentation/cubit/invoices_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/invoices_state.dart';
import 'package:finly/features/cards/presentation/pages/installment_form_page.dart';
import 'package:finly/features/cards/presentation/pages/invoice_detail_page.dart';
import 'package:finly/features/cards/presentation/widgets/card_usage_summary.dart';
import 'package:finly/features/cards/presentation/widgets/invoice_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Everything about the card in front of the carousel: its limit, the
/// invoice that matters now, the other invoices and installment purchases.
class CardDetailsSection extends StatelessWidget {
  final WorkspaceEntity workspace;
  final CreditCardEntity card;
  final DateTime today;

  /// Something changed the card (a payment, a purchase): the list of cards
  /// reads again, for the used limit.
  final VoidCallback onChanged;

  const CardDetailsSection({
    super.key,
    required this.workspace,
    required this.card,
    required this.today,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<InvoicesCubit>()..load(card),
      child: _Details(workspace: workspace, card: card, today: today, onChanged: onChanged),
    );
  }
}

class _Details extends StatelessWidget {
  final WorkspaceEntity workspace;
  final CreditCardEntity card;
  final DateTime today;
  final VoidCallback onChanged;

  const _Details({
    required this.workspace,
    required this.card,
    required this.today,
    required this.onChanged,
  });

  Future<void> _openInvoice(
    BuildContext context,
    CreditCardEntity current,
    InvoiceEntity invoice, {
    bool pay = false,
  }) async {
    final cubit = context.read<InvoicesCubit>();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => InvoiceDetailPage(
          workspace: workspace,
          card: current,
          invoice: invoice,
          startPaying: pay,
        ),
      ),
    );
    // Paying changes the invoice and the used limit.
    await cubit.reload();
    onChanged();
  }

  Future<void> _openInstallments(BuildContext context, CreditCardEntity current) async {
    final cubit = context.read<InvoicesCubit>();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => InstallmentFormPage(card: current)),
    );
    if (created == true) {
      await cubit.reload();
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InvoicesCubit, InvoicesState>(
      builder: (context, state) {
        final current = state.card ?? card;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: CardUsageSummary(card: current),
            ),
            const SizedBox(height: 24),
            ..._invoices(context, state, current),
            const SizedBox(height: 24),
            GroupedSection(
              items: [
                GroupedItem(
                  icon: Icons.splitscreen,
                  title: 'Compra parcelada',
                  subtitle: 'Lança as parcelas nas próximas faturas',
                  onTap: () => _openInstallments(context, current),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  List<Widget> _invoices(BuildContext context, InvoicesState state, CreditCardEntity current) {
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
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Nenhuma fatura ainda. A primeira aparece quando você lança uma '
              'compra neste cartão.',
              style: text.bodyMedium,
            ),
          ),
        ),
      ];
    }

    final highlighted = currentInvoice(state.invoices, today);
    final others = [
      for (final invoice in state.invoices)
        if (invoice != highlighted) invoice,
    ];

    return [
      if (highlighted != null)
        InvoiceSummaryCard(
          invoice: highlighted,
          currency: current.currency,
          today: today,
          onPay: () => _openInvoice(context, current, highlighted, pay: true),
          onOpen: () => _openInvoice(context, current, highlighted),
        ),
      if (others.isNotEmpty) ...[
        if (highlighted != null) const SizedBox(height: 24),
        SectionLabel(highlighted == null ? 'Faturas' : 'Outras faturas'),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < others.length; i++) ...[
                if (i > 0) const Divider(),
                InvoiceRow(
                  invoice: others[i],
                  currency: current.currency,
                  today: today,
                  onTap: () => _openInvoice(context, current, others[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    ];
  }
}
