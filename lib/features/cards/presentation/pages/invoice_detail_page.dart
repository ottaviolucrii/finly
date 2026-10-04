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
import 'package:finly/features/cards/presentation/cubit/invoice_detail_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/invoice_detail_state.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/presentation/transaction_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// One invoice: its period, due date, total and the purchases inside it.
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
      create: (_) => sl<InvoiceDetailCubit>()..load(invoice.id),
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isBusiness = workspace.type == WorkspaceType.business;

    return Scaffold(
      appBar: AppBar(
        title: Text('Fatura ${monthYearLabel(invoice.referenceMonth)}'),
        backgroundColor: isBusiness ? AppColors.deepBlue : null,
        foregroundColor: isBusiness ? AppColors.white : null,
      ),
      body: BlocBuilder<InvoiceDetailCubit, InvoiceDetailState>(
        builder: (context, state) {
          return ListView(
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
                        Money(invoice.totalCents, card.currency).format(),
                        style: text.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(invoiceStatusIcon(invoice.status), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            invoiceStatusLabel(invoice.status),
                            style: text.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Período: ${formatDateBr(invoice.periodStart)} a '
                        '${formatDateBr(invoice.periodEnd)}',
                        style: text.bodySmall,
                      ),
                      Text(
                        'Vencimento: ${formatDateBr(invoice.dueDate)}',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Compras', style: text.titleMedium),
              const SizedBox(height: 8),
              ..._purchases(context, state),
            ],
          );
        },
      ),
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