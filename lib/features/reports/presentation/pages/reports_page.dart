import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/core/widgets/workspace_title.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:finly/features/reports/domain/entities/monthly_report.dart';
import 'package:finly/features/reports/domain/report_rules.dart';
import 'package:finly/features/reports/presentation/cubit/export_cubit.dart';
import 'package:finly/features/reports/presentation/cubit/export_state.dart';
import 'package:finly/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:finly/features/reports/presentation/cubit/reports_state.dart';
import 'package:finly/features/reports/presentation/reports_messages.dart';
import 'package:finly/features/reports/presentation/widgets/pdf_export_button.dart';
import 'package:finly/features/transactions/presentation/widgets/statement_band.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The monthly report of one workspace. The cubits are created for
/// [workspace], so they never show data of another workspace.
class ReportsPage extends StatelessWidget {
  final WorkspaceEntity workspace;

  const ReportsPage({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<ReportsCubit>()..load(workspace.id)),
        BlocProvider(create: (_) => sl<ExportCubit>()),
      ],
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isBusiness = widget.workspace.type == WorkspaceType.business;

    return BlocListener<ExportCubit, ExportState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == ExportStatus.failure && state.failure != null) {
          _showMessage(reportsFailureMessage(state.failure!));
        } else if (state.status == ExportStatus.done && state.truncated) {
          _showMessage(
            'O mês tem muitas transações: foram exportadas as primeiras '
            '${state.rowCount}.',
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: WorkspaceTitle('Relatório', isBusiness: isBusiness),
          backgroundColor: isBusiness ? AppColors.deepBlue : null,
          foregroundColor: isBusiness ? AppColors.white : null,
          actions: [
            PdfExportButton(workspace: widget.workspace),
            BlocBuilder<ExportCubit, ExportState>(
              builder: (context, export) {
                final busy = export.status == ExportStatus.exporting;

                return IconButton(
                  tooltip: 'Exportar o mês em CSV',
                  icon: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share),
                  onPressed: busy
                      ? null
                      : () => context.read<ExportCubit>().export(
                            workspaceId: widget.workspace.id,
                            month: context.read<ReportsCubit>().state.month,
                          ),
                );
              },
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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

    Widget arrow(IconData icon, String tooltip, VoidCallback? onPressed) => Material(
          color: Theme.of(context).colorScheme.surface,
          shape: const CircleBorder(),
          elevation: 1,
          child: IconButton(tooltip: tooltip, icon: Icon(icon), onPressed: onPressed),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          arrow(Icons.chevron_left, 'Mês anterior', onPrevious),
          Text(monthTitle(month), style: text.titleLarge?.copyWith(fontSize: 17)),
          arrow(Icons.chevron_right, 'Próximo mês', canGoNext ? onNext : null),
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

  Widget _tile(String label, int cents, int previousCents, {Color valueColor = AppColors.white, bool signed = false}) {
    final money = Money(cents, report.currency);
    final value = signed && cents > 0 ? '+ ${money.format()}' : money.format();
    final comparison = comparisonText(cents, previousCents);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.onBand)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: valueColor),
              ),
            ),
            if (comparison.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  comparison,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 11, color: AppColors.onBand),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final net = report.netCents;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.deepBlue, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumo do mês',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.white),
          ),
          const Text('Só o que já aconteceu', style: TextStyle(fontSize: 12, color: AppColors.onBand)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tile('Entradas', report.incomeCents, report.previousIncomeCents),
              const SizedBox(width: 8),
              _tile('Saídas', report.expenseCents, report.previousExpenseCents, valueColor: AppColors.goldOnBand),
              const SizedBox(width: 8),
              _tile(
                net >= 0 ? 'Sobrou' : 'Faltou',
                net,
                report.previousNetCents,
                signed: true,
                valueColor: net < 0 ? AppColors.dangerOnDark : AppColors.white,
              ),
            ],
          ),
        ],
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
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
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
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
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