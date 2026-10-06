import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/accounts/presentation/pages/accounts_page.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/budgets/presentation/budget_style.dart';
import 'package:finly/features/budgets/presentation/pages/budgets_page.dart';
import 'package:finly/features/dashboard/domain/entities/dashboard_data.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:finly/features/dashboard/presentation/dashboard_messages.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/presentation/pages/transactions_page.dart';
import 'package:finly/features/transactions/presentation/transaction_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens [page] and refreshes the dashboard when the user comes back, because
/// anything done there (a purchase, a payment, a budget) changes the numbers.
Future<void> openAndRefresh(BuildContext context, Widget page) async {
  final cubit = context.read<DashboardCubit>();
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => page),
  );
  await cubit.reload();
}

/// The summary of one workspace: balance, month, budgets and what is coming.
class DashboardView extends StatelessWidget {
  final WorkspaceEntity workspace;

  const DashboardView({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        final data = state.data;

        if (data == null) {
          if (state.status == DashboardStatus.failure && state.failure != null) {
            return _ErrorCard(
              message: dashboardFailureMessage(state.failure!),
              onRetry: () => context.read<DashboardCubit>().reload(),
            );
          }
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BalanceCard(data: data, workspace: workspace),
            const SizedBox(height: 12),
            _MonthCard(data: data),
            const SizedBox(height: 12),
            _BudgetsCard(data: data, workspace: workspace),
            const SizedBox(height: 12),
            _UpcomingCard(data: data, workspace: workspace),
          ],
        );
      },
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final DashboardData data;
  final WorkspaceEntity workspace;

  const _BalanceCard({required this.data, required this.workspace});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openAndRefresh(context, AccountsPage(workspace: workspace)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Saldo', style: text.titleMedium),
              const SizedBox(height: 8),
              if (!data.hasAccounts)
                Text(
                  'Nenhuma conta ainda. Toque para criar a primeira.',
                  style: text.bodyMedium,
                )
              else
                for (final balance in data.balances) ...[
                  Text(
                    balance.posted.format(),
                    style: text.headlineSmall?.copyWith(
                      color: balance.posted.isNegative ? scheme.error : null,
                    ),
                  ),
                  if (balance.hasPendingEffect)
                    Text(
                      'Previsto: ${balance.projected.format()}',
                      style: text.bodySmall,
                    ),
                  if (balance.cardDebtCents > 0)
                    Text(
                      'Cartões em uso: ${balance.cardDebt.format()}',
                      style: text.bodySmall,
                    ),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  final DashboardData data;

  const _MonthCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Este mês · ${monthYearLabel(data.month)}',
              style: text.titleMedium,
            ),
            const SizedBox(height: 8),
            if (data.flows.isEmpty)
              Text('Nenhum lançamento neste mês.', style: text.bodyMedium)
            else
              for (final flow in data.flows) ...[
                if (data.flows.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(flow.currency, style: text.labelLarge),
                  ),
                _FlowRows(flow: flow),
              ],
          ],
        ),
      ),
    );
  }
}

class _FlowRows extends StatelessWidget {
  final CurrencyFlow flow;

  const _FlowRows({required this.flow});

  Widget _row(BuildContext context, String label, String value, {Color? color}) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.bodyMedium)),
          Text(value, style: text.titleSmall?.copyWith(color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final result = flow.money(flow.resultPostedCents);

    final pending = <String>[
      if (flow.incomePendingCents > 0)
        '+ ${flow.money(flow.incomePendingCents).format()}',
      if (flow.expensePendingCents > 0)
        '- ${flow.money(flow.expensePendingCents).format()}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(
          context,
          'Entradas',
          '+ ${flow.money(flow.incomePostedCents).format()}',
          color: scheme.primary,
        ),
        _row(
          context,
          'Saídas',
          '- ${flow.money(flow.expensePostedCents).format()}',
        ),
        _row(
          context,
          'Resultado',
          result.format(),
          color: result.isNegative ? scheme.error : null,
        ),
        if (flow.hasPending)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Pendentes: ${pending.join(' · ')}',
              style: text.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _BudgetsCard extends StatelessWidget {
  final DashboardData data;
  final WorkspaceEntity workspace;

  const _BudgetsCard({required this.data, required this.workspace});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Orçamentos', style: text.titleMedium)),
                TextButton(
                  onPressed: () =>
                      openAndRefresh(context, BudgetsPage(workspace: workspace)),
                  child: Text(data.budgets.isEmpty ? 'Definir' : 'Ver todos'),
                ),
              ],
            ),
            if (data.budgets.isEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'Nenhum orçamento neste mês.',
                  style: text.bodyMedium,
                ),
              )
            else
              for (final item in data.budgets) _BudgetLine(item: item),
          ],
        ),
      ),
    );
  }
}

class _BudgetLine extends StatelessWidget {
  final BudgetProgress item;

  const _BudgetLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final color = budgetLevelColor(context, item.level);
    final label = budgetLevelLabel(item.level);

    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.category.name,
                  style: text.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (label != null)
                Text(
                  label,
                  style: text.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: item.ratio.clamp(0.0, 1.0).toDouble(),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: color,
            backgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 4),
          Text(
            '${item.spent.format()} de ${item.limit.format()}',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  final DashboardData data;
  final WorkspaceEntity workspace;

  const _UpcomingCard({required this.data, required this.workspace});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Próximos lançamentos', style: text.titleMedium),
                ),
                TextButton(
                  onPressed: () => openAndRefresh(
                    context,
                    TransactionsPage(workspace: workspace),
                  ),
                  child: const Text('Ver todos'),
                ),
              ],
            ),
            if (data.upcoming.isEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'Nada pendente nos próximos 14 dias.',
                  style: text.bodyMedium,
                ),
              )
            else
              for (final transaction in data.upcoming)
                _UpcomingLine(transaction: transaction, today: today),
          ],
        ),
      ),
    );
  }
}

class _UpcomingLine extends StatelessWidget {
  final TransactionEntity transaction;
  final DateTime today;

  const _UpcomingLine({required this.transaction, required this.today});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final due = DateTime(
      transaction.occurredAt.year,
      transaction.occurredAt.month,
      transaction.occurredAt.day,
    );
    final overdue = due.isBefore(today);
    final date = formatDateBr(transaction.occurredAt);

    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: text.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  overdue ? '$date · Atrasada' : date,
                  style: text.bodySmall?.copyWith(
                    color: overdue ? scheme.error : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            transactionAmountText(transaction),
            style: text.titleSmall?.copyWith(
              color: transaction.type.isCredit ? scheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Tentar de novo')),
          ],
        ),
      ),
    );
  }
}