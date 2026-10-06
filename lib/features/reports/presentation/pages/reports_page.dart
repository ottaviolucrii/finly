import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:finly/features/reports/domain/entities/monthly_report.dart';
import 'package:finly/features/reports/domain/report_rules.dart';
import 'package:finly/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:finly/features/reports/presentation/cubit/reports_state.dart';
import 'package:finly/features/reports/presentation/reports_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The monthly report of one workspace. The cubit is created for [workspace],
/// so it never shows data of another workspace.
class ReportsPage extends StatelessWidget {
  final WorkspaceEntity workspace;

  const ReportsPage({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ReportsCubit>()..load(workspace.id),
      child: _ReportsView(workspace: workspace),
    );
  }
}

class _ReportsView extends StatefulWidget {
  final WorkspaceEntity workspace;

  const _ReportsView({required this.workspace});

  @override
  State<_ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<_ReportsView> {
  String? _currency;

  @override
  Widget build(BuildContext context) {
    final isBusiness = widget.workspace.type == WorkspaceType.business;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório'),
        backgroundColor: isBusiness ? AppColors.deepBlue : null,
        foregroundColor: isBusiness ? AppColors.white : null,
      ),
      body: BlocBuilder<ReportsCubit, ReportsState>(
        builder: (context, state) {
          final cubit = context.read<ReportsCubit>();

          return Column(
            children: [
              _MonthHeader(
                month: state.month,
                canGoNext: state.canGoNext,
                onPrevious: cubit.previousMonth,
                onNext: cubit.nextMonth,
              ),
              if (state.status == ReportsStatus.loading && state.report != null)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(child: _body(context, state)),
            ],
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, ReportsState state) {
    final report = state.report;
    final cubit = context.read<ReportsCubit>();

    if (report == null) {
      if (state.status == ReportsStatus.failure) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reportsFailureMessage(state.failure!),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: cubit.reload,
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (report.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhuma movimentação neste mês.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // No firstWhere(orElse): a plain loop, to stay safe with model types.
    var selected = report.byCurrency.first;
    for (final item in report.byCurrency) {
      if (item.currency == _currency) selected = item;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (report.byCurrency.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final item in report.byCurrency)
                  ChoiceChip(
                    label: Text(item.currency),
                    selected: item.currency == selected.currency,
                    onSelected: (_) => setState(() => _currency = item.currency),
                  ),
              ],
            ),
          ),
        _SummaryCard(report: selected),
        const SizedBox(height: 12),
        _CategoriesCard(report: selected),
        const SizedBox(height: 12),
        _TopExpensesCard(report: selected),
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthHeader({
    required this.month,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Mês anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Expanded(
            child: Text(
              monthYearLabel(month),
              style: text.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            tooltip: 'Próximo mês',
            icon: const Icon(Icons.chevron_right),
            onPressed: canGoNext ? onNext : null,
          ),
        ],
      ),
    );
  }
}

/// "▲ 12% vs mês anterior": the arrow, not only a colour, says the direction.
String comparisonText(int current, int previous) {
  final change = percentChange(current, previous);
  if (change == null) {
    return current == 0 ? '' : 'sem dados no mês anterior';
  }
  if (change == 0) return '= igual ao mês anterior';
  return '${change > 0 ? '▲' : '▼'} ${change.abs()}% vs mês anterior';
}

class _SummaryCard extends StatelessWidget {
  final CurrencyReport report;

  const _SummaryCard({required this.report});

  Widget _row(
    BuildContext context,
    String label,
    int cents,
    int previousCents, {
    bool signed = false,
  }) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final money = Money(cents, report.currency);
    final value = signed && cents > 0 ? '+ ${money.format()}' : money.format();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: text.bodyLarge)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: text.titleMedium?.copyWith(
                  color: signed && cents < 0 ? scheme.error : null,
                ),
              ),
              if (comparisonText(cents, previousCents).isNotEmpty)
                Text(comparisonText(cents, previousCents), style: text.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumo do mês', style: text.titleMedium),
            Text('Só o que já aconteceu', style: text.bodySmall),
            const SizedBox(height: 8),
            _row(context, 'Entradas', report.incomeCents, report.previousIncomeCents),
            _row(context, 'Saídas', report.expenseCents, report.previousExpenseCents),
            const Divider(),
            _row(
              context,
              'Resultado',
              report.netCents,
              report.previousNetCents,
              signed: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriesCard extends StatelessWidget {
  final CurrencyReport report;

  const _CategoriesCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = report.categoryTotalCents;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gastos por categoria', style: text.titleMedium),
            Text('Inclui lançamentos pendentes', style: text.bodySmall),
            const SizedBox(height: 8),
            if (report.categories.isEmpty)
              Text('Nenhum gasto neste mês.', style: text.bodyMedium)
            else
              for (final row in report.categories)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: categoryColor(row.colorHex),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(row.name, style: text.bodyMedium),
                            if (comparisonText(row.spentCents, row.previousCents)
                                .isNotEmpty)
                              Text(
                                comparisonText(row.spentCents, row.previousCents),
                                style: text.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Money(row.spentCents, report.currency).format(),
                            style: text.titleSmall,
                          ),
                          if (total > 0)
                            Text(
                              '${(row.spentCents * 100 / total).round()}% do total',
                              style: text.bodySmall,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _TopExpensesCard extends StatelessWidget {
  final CurrencyReport report;

  const _TopExpensesCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Maiores despesas', style: text.titleMedium),
            const SizedBox(height: 8),
            if (report.topExpenses.isEmpty)
              Text('Nenhuma despesa neste mês.', style: text.bodyMedium)
            else
              for (final expense in report.topExpenses)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expense.description,
                              style: text.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              expense.isPending
                                  ? '${formatDateBr(expense.occurredAt)} · pendente'
                                  : formatDateBr(expense.occurredAt),
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Money(expense.amountCents, report.currency).format(),
                        style: text.titleSmall,
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}