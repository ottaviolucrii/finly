import 'package:finly/core/di/injection.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/budgets/domain/entities/budget_overview.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/budgets/presentation/budget_messages.dart';
import 'package:finly/features/budgets/presentation/budget_style.dart';
import 'package:finly/features/budgets/presentation/cubit/budgets_cubit.dart';
import 'package:finly/features/budgets/presentation/cubit/budgets_state.dart';
import 'package:finly/features/budgets/presentation/pages/budget_form_page.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Budgets of one workspace, month by month. The cubit is created for
/// [workspace], so it never shows budgets of another workspace.
class BudgetsPage extends StatelessWidget {
  final WorkspaceEntity workspace;

  const BudgetsPage({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BudgetsCubit>()..load(workspace.id),
      child: _BudgetsView(workspace: workspace),
    );
  }
}

class _BudgetsView extends StatelessWidget {
  final WorkspaceEntity workspace;

  const _BudgetsView({required this.workspace});

  Future<void> _openForm(
    BuildContext context,
    BudgetsState state, {
    BudgetProgress? editing,
  }) async {
    final overview = state.overview;
    if (overview == null) return;

    final cubit = context.read<BudgetsCubit>();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BudgetFormPage(
          workspaceId: workspace.id,
          month: state.month,
          categories: overview.expenseCategories,
          editing: editing,
        ),
      ),
    );
    if (saved == true) await cubit.reload();
  }

  Future<void> _confirmStop(
    BuildContext context,
    BudgetProgress item,
    DateTime month,
  ) async {
    final cubit = context.read<BudgetsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Parar este orçamento?'),
        content: Text(
          'O orçamento de "${item.category.name}" deixa de valer a partir de '
          '${monthYearLabel(month)}. Os meses anteriores não mudam.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Parar orçamento'),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.stopBudget(item);
  }

  @override
  Widget build(BuildContext context) {
    final isBusiness = workspace.type == WorkspaceType.business;

    return BlocConsumer<BudgetsCubit, BudgetsState>(
      listenWhen: (previous, current) =>
          current.actionFailure != null &&
          previous.actionFailure != current.actionFailure,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(budgetFailureMessage(state.actionFailure!))),
          );
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Orçamentos'),
            backgroundColor: isBusiness ? AppColors.deepBlue : null,
            foregroundColor: isBusiness ? AppColors.white : null,
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed:
                state.overview == null ? null : () => _openForm(context, state),
            icon: const Icon(Icons.add),
            label: const Text('Definir orçamento'),
          ),
          body: Column(
            children: [
              _MonthSelector(
                month: state.month,
                onPrevious: () => context.read<BudgetsCubit>().changeMonth(-1),
                onNext: () => context.read<BudgetsCubit>().changeMonth(1),
              ),
              Expanded(child: _body(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, BudgetsState state) {
    if (state.status == BudgetsStatus.failure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                budgetFailureMessage(state.failure!),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.read<BudgetsCubit>().reload(),
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      );
    }

    final overview = state.overview;
    if (overview == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (overview.items.isEmpty) return _EmptyView(overview: overview);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        for (final item in overview.items)
          _BudgetTile(
            item: item,
            onEdit: () => _openForm(context, state, editing: item),
            onStop: () => _confirmStop(context, item, state.month),
          ),
      ],
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthSelector({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Mês anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Text(monthYearLabel(month), style: text.titleMedium),
          IconButton(
            tooltip: 'Próximo mês',
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  final BudgetProgress item;
  final VoidCallback onEdit;
  final VoidCallback onStop;

  const _BudgetTile({
    required this.item,
    required this.onEdit,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final level = item.level;
    final color = budgetLevelColor(context, level);
    final label = budgetLevelLabel(level);

    final categoryTint = categoryColor(item.category.colorHex);
    final iconColor =
        ThemeData.estimateBrightnessForColor(categoryTint) == Brightness.dark
            ? AppColors.white
            : AppColors.midnight;

    final remaining = item.remainingCents >= 0
        ? 'Restam ${item.remaining.format()}'
        : 'Estourou ${item.remaining.format().replaceFirst('-', '')}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: categoryTint,
                    foregroundColor: iconColor,
                    child: Icon(categoryIcon(item.category.icon)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.category.name,
                      style: text.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Mais opções',
                    onSelected: (_) => onStop(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'stop',
                        child: Text('Parar a partir deste mês'),
                      ),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: item.ratio.clamp(0.0, 1.0).toDouble(),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      color: color,
                      backgroundColor: scheme.onSurface.withValues(alpha: 0.12),
                    ),
                    const SizedBox(height: 8),
                    // A Wrap, not a Row: with long amounts the second text
                    // drops to the next line instead of overflowing.
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 2,
                        children: [
                          Text(
                            '${item.spent.format()} de ${item.limit.format()}',
                            style: text.bodyMedium,
                          ),
                          Text(remaining, style: text.bodyMedium),
                        ],
                      ),
                    ),
                    if (label != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          label,
                          style: text.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final BudgetOverview overview;

  const _EmptyView({required this.overview});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pie_chart_outline, size: 56),
            const SizedBox(height: 16),
            Text('Nenhum orçamento neste mês', style: text.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Toque em "Definir orçamento" para limitar os gastos de uma '
              'categoria. Ele vale a partir deste mês, até você definir outro.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}