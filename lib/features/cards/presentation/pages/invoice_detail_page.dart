import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/presentation/card_messages.dart';
import 'package:finly/features/cards/presentation/card_style.dart';
import 'package:finly/features/cards/presentation/cubit/invoice_detail_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/invoice_detail_state.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/presentation/transaction_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// One invoice: its period, due date, total, the purchases inside it, and the
/// button to pay it.
class InvoiceDetailPage extends StatelessWidget {
  final WorkspaceEntity workspace;
  final CreditCardEntity card;
  final InvoiceEntity invoice;

  const InvoiceDetailPage({
    super.key,
    required this.workspace,
    required this.card,
    required this.invoice,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<InvoiceDetailCubit>()..load(invoice, card),
      child: _InvoiceDetailView(workspace: workspace, card: card, invoice: invoice),
    );
  }
}

class _InvoiceDetailView extends StatelessWidget {
  final WorkspaceEntity workspace;
  final CreditCardEntity card;
  final InvoiceEntity invoice;

  const _InvoiceDetailView({
    required this.workspace,
    required this.card,
    required this.invoice,
  });

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openPaySheet(
    BuildContext context,
    InvoiceEntity current,
    List<AccountEntity> sources,
  ) {
    // The sheet lives in its own route, so hand it the cubit explicitly.
    final cubit = context.read<InvoiceDetailCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PaySheet(
        invoice: current,
        card: card,
        sources: sources,
        onConfirm: cubit.pay,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isBusiness = workspace.type == WorkspaceType.business;

    return BlocConsumer<InvoiceDetailCubit, InvoiceDetailState>(
      listenWhen: (previous, current) =>
          (current.actionFailure != null &&
              previous.actionFailure != current.actionFailure) ||
          (previous.invoice != null &&
              !previous.invoice!.isPaid &&
              (current.invoice?.isPaid ?? false)),
      listener: (context, state) {
        final failure = state.actionFailure;
        if (failure != null) {
          _showMessage(context, cardFailureMessage(failure));
        } else {
          _showMessage(context, 'Fatura paga.');
        }
      },
      builder: (context, state) {
        final current = state.invoice ?? invoice;
        final status = current.statusOn(DateTime.now());

        return Scaffold(
          appBar: AppBar(
            title: Text('Fatura ${monthYearLabel(current.referenceMonth)}'),
            backgroundColor: isBusiness ? AppColors.deepBlue : null,
            foregroundColor: isBusiness ? AppColors.white : null,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.name, style: text.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        Money(current.totalCents, card.currency).format(),
                        style: text.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(invoiceStatusIcon(status), size: 16),
                          const SizedBox(width: 6),
                          Text(invoiceStatusLabel(status), style: text.bodyMedium),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Período: ${formatDateBr(current.periodStart)} a '
                        '${formatDateBr(current.periodEnd)}',
                        style: text.bodySmall,
                      ),
                      Text(
                        'Vencimento: ${formatDateBr(current.dueDate)}',
                        style: text.bodySmall,
                      ),
                      if (current.needsPayment) ...[
                        const SizedBox(height: 16),
                        if (state.paying)
                          const LinearProgressIndicator()
                        else
                          FilledButton.icon(
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Pagar fatura'),
                            onPressed: state.status == InvoiceDetailStatus.loaded
                                ? () => _openPaySheet(
                                      context,
                                      current,
                                      state.accounts,
                                    )
                                : null,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Compras', style: text.titleMedium),
              const SizedBox(height: 8),
              ..._purchases(context, state),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _purchases(BuildContext context, InvoiceDetailState state) {
    final text = Theme.of(context).textTheme;

    if (state.status == InvoiceDetailStatus.failure) {
      return [
        Text(cardFailureMessage(state.failure!)),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => context.read<InvoiceDetailCubit>().reload(),
          child: const Text('Tentar de novo'),
        ),
      ];
    }
    if (state.status != InvoiceDetailStatus.loaded && state.transactions.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (state.transactions.isEmpty) {
      return [Text('Nenhuma compra nesta fatura.', style: text.bodyMedium)];
    }

    return [
      for (final transaction in state.transactions)
        _PurchaseTile(transaction: transaction),
    ];
  }
}

class _PurchaseTile extends StatelessWidget {
  final TransactionEntity transaction;

  const _PurchaseTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final date = formatDateBr(transaction.occurredAt);
    final subtitle = transaction.isPending ? '$date · Pendente' : date;

    return Card(
      child: ListTile(
        title: Text(
          transaction.description,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(subtitle),
        trailing: Text(
          transactionAmountText(transaction),
          style: text.titleMedium?.copyWith(
            color: transaction.type.isCredit ? scheme.primary : null,
          ),
        ),
      ),
    );
  }
}

/// Lets the user choose which account pays the invoice.
class _PaySheet extends StatefulWidget {
  final InvoiceEntity invoice;
  final CreditCardEntity card;
  final List<AccountEntity> sources;
  final void Function(String accountId) onConfirm;

  const _PaySheet({
    required this.invoice,
    required this.card,
    required this.sources,
    required this.onConfirm,
  });

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = Money(widget.invoice.totalCents, widget.card.currency).format();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pagar fatura ${monthYearLabel(widget.invoice.referenceMonth)}',
              style: text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(total, style: text.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (widget.sources.isEmpty)
              Text(
                'Você precisa de uma conta em ${widget.card.currency} (que não '
                'seja um cartão) para pagar. Crie uma em Contas.',
                textAlign: TextAlign.center,
              )
            else ...[
              Text('Pagar com', style: text.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final account in widget.sources)
                    ChoiceChip(
                      label: Text('${account.name} · ${account.postedBalance.format()}'),
                      selected: _selected == account.id,
                      onSelected: (_) => setState(() => _selected = account.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _selected == null
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      widget.onConfirm(_selected!);
                    },
              child: Text('Pagar $total'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}