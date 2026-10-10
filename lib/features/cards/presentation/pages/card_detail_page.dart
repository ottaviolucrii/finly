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
import 'package:finly/features/cards/presentation/cubit/card_archive_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/card_archive_state.dart';
import 'package:finly/features/cards/presentation/cubit/invoices_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/invoices_state.dart';
import 'package:finly/features/cards/presentation/pages/card_edit_page.dart';
import 'package:finly/features/cards/presentation/pages/installment_form_page.dart';
import 'package:finly/features/cards/presentation/pages/invoice_detail_page.dart';
import 'package:finly/features/cards/presentation/widgets/card_usage_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// One card: its limit, installment purchases, its invoices, and the menu to
/// edit or archive it.
class CardDetailPage extends StatelessWidget {
  final WorkspaceEntity workspace;
  final CreditCardEntity card;

  const CardDetailPage({super.key, required this.workspace, required this.card});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<InvoicesCubit>()..load(card)),
        BlocProvider(create: (_) => sl<CardArchiveCubit>()),
      ],
      child: _CardDetailView(workspace: workspace, card: card),
    );
  }
}

class _CardDetailView extends StatelessWidget {
  final WorkspaceEntity workspace;
  final CreditCardEntity card;

  const _CardDetailView({required this.workspace, required this.card});

  CreditCardEntity _current(BuildContext context) =>
      context.read<InvoicesCubit>().state.card ?? card;

  Future<void> _openEdit(BuildContext context) async {
    final cubit = context.read<InvoicesCubit>();
    final current = _current(context);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => CardEditPage(card: current)),
    );
    // The card is read again, so the name, limit and days show right away.
    if (saved == true) await cubit.reload();
  }

  Future<void> _archive(BuildContext context) async {
    final current = _current(context);
    final archiveCubit = context.read<CardArchiveCubit>();

    if (current.usedCents > 0) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Este cartão está em uso'),
          content: Text(
            'Ainda há ${current.used.format()} em aberto. Pague as faturas '
            'antes de arquivar: um cartão arquivado some das listas e você '
            'não conseguiria mais pagá-las.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Arquivar cartão?'),
        content: Text(
          '"${current.name}" sai da lista de cartões, mas o histórico é '
          'mantido. Você pode restaurá-lo em Contas, na seção "Arquivadas".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Arquivar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await archiveCubit.archive(current.accountId);
  }

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

    return BlocListener<CardArchiveCubit, CardArchiveState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        if (state.status == CardArchiveStatus.failure && state.failure != null) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(cardFailureMessage(state.failure!))),
            );
        }
        if (state.status == CardArchiveStatus.archived) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'Cartão arquivado. Para trazê-lo de volta, use Contas, '
                  'seção "Arquivadas".',
                ),
              ),
            );
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(card.name),
          backgroundColor: isBusiness ? AppColors.deepBlue : null,
          foregroundColor: isBusiness ? AppColors.white : null,
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Mais opções',
              onSelected: (value) {
                if (value == 'edit') {
                  _openEdit(context);
                } else {
                  _archive(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar cartão')),
                PopupMenuItem(value: 'archive', child: Text('Arquivar cartão')),
              ],
            ),
          ],
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
                          current.name,
                          style: text.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                  if (invoice.isPartiallyPaid)
                    Text(
                      'Falta ${Money(invoice.remainingCents, currency).format()}',
                      style: text.bodySmall,
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(invoiceDisplayIcon(invoice, today), size: 14),
                      const SizedBox(width: 4),
                      Text(invoiceDisplayLabel(invoice, today), style: text.bodySmall),
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