import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/widgets/grouped_list.dart';
import 'package:finly/core/widgets/workspace_title.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/budgets/domain/entities/budget_overview.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/budgets/presentation/budget_messages.dart';
import 'package:finly/features/budgets/presentation/cubit/budgets_cubit.dart';
import 'package:finly/features/budgets/presentation/cubit/budgets_state.dart';
import 'package:finly/features/budgets/presentation/pages/budget_form_page.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:finly/features/shell/presentation/plan_cards.dart';
import 'package:finly/features/transactions/presentation/widgets/statement_band.dart';
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
            title: WorkspaceTitle('Orçamentos', isBusiness: isBusiness),
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

    final today = DateTime.now();
    final sorted = closestToLimit(overview.items, count: overview.items.length);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      children: [
        _TotalRing(items: overview.items, month: state.month, today: today),
        const SizedBox(height: 20),
        const SectionLabel('Por categoria'),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < sorted.length; i++) ...[
                if (i > 0) const Divider(),
                _BudgetTile(
                  item: sorted[i],
                  month: state.month,
                  today: today,
                  onEdit: () => _openForm(context, state, editing: sorted[i]),
                  onStop: () => _confirmStop(context, sorted[i], state.month),
                ),
              ],
            ],
          ),
        ),
        if (overview.withoutBudget.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionLabel('Sem orçamento'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in overview.withoutBudget)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(category.name),
                  onPressed: () => _openForm(context, state),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// How much is left per day until the end of [month], counting today; null
/// when it is not the current month or nothing is left.
int? dailyAllowanceCents(int remainingCents, DateTime month, DateTime today) {
  if (remainingCents <= 0 || month.year != today.year || month.month != today.month) return null;
  final last = DateTime(month.year, month.month + 1, 0).day;
  final days = last - today.day + 1;
  return days <= 0 ? null : remainingCents ~/ days;
}

/// The top card: a ring with the share of all limits already spent, and how
/// much is left in the month.
class _TotalRing extends StatelessWidget {
  final List<BudgetProgress> items;
  final DateTime month;
  final DateTime today;

  const _TotalRing({required this.items, required this.month, required this.today});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final totals = budgetTotals(items);
    final ratio = totals.limitCents <= 0 ? 0.0 : totals.spentCents / totals.limitCents;
    final left = totals.limitCents - totals.spentCents;
    final sameMonth = month.year == today.year && month.month == today.month;
    final daysLeft = DateTime(month.year, month.month + 1, 0).day - today.day;
    String money(int cents) => Money(cents, totals.currency).format();

    final details = [
      if (sameMonth) daysLeft <= 0 ? 'Último dia do mês' : 'Faltam $daysLeft ${daysLeft == 1 ? 'dia' : 'dias'}',
      left >= 0 ? 'sobram ${money(left)}' : 'passou ${money(-left)}',
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    strokeWidth: 9,
                    color: ratio > 1 ? scheme.error : scheme.primary,
                    backgroundColor: dark ? AppColors.borderDark : AppColors.track,
                  ),
                  Center(
                    child: Text(
                      '${(ratio * 100).floor()}%',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gasto do total dos orçamentos',
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  Text(
                    '${money(totals.spentCents)} de ${money(totals.limitCents)}',
                    style: text.titleLarge?.copyWith(fontSize: 19),
                  ),
                  Text(
                    details,
                    style: text.bodySmall?.copyWith(
                      color: left < 0 ? scheme.error : scheme.onSurfaceVariant,
                      fontWeight: left < 0 ? FontWeight.w600 : null,
                    ),
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

    Widget arrow(IconData icon, String tooltip, VoidCallback onPressed) => Material(
          color: Theme.of(context).colorScheme.surface,
          shape: const CircleBorder(),
          elevation: 1,
          child: IconButton(tooltip: tooltip, icon: Icon(icon), onPressed: onPressed),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          arrow(Icons.chevron_left, 'Mês anterior', onPrevious),
          Text(monthTitle(month), style: text.titleLarge?.copyWith(fontSize: 17)),
          arrow(Icons.chevron_right, 'Próximo mês', onNext),
        ],
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  final BudgetProgress item;
  final DateTime month;
  final DateTime today;
  final VoidCallback onEdit;
  final VoidCallback onStop;

  const _BudgetTile({
    required this.item,
    required this.month,
    required this.today,
    required this.onEdit,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final level = item.level;
    final color = switch (level) {
      BudgetLevel.over => scheme.error,
      BudgetLevel.warning => AppColors.gold,
      BudgetLevel.normal => scheme.primary,
    };
    final tint = categoryColor(item.category.colorHex);
    final perDay = dailyAllowanceCents(item.remainingCents, month, today);

    final String note;
    if (level == BudgetLevel.over) {
      note = 'Passou ${Money(-item.remainingCents, item.currency).format()}';
    } else if (level == BudgetLevel.warning) {
      note = 'Perto do limite · sobram ${item.remaining.format()}';
    } else if (perDay != null) {
      note = 'Sobram ${item.remaining.format()} · uns ${Money(perDay, item.currency).format()} por dia';
    } else {
      note = 'Sobram ${item.remaining.format()}';
    }
    final noteColor = switch (level) {
      BudgetLevel.over => scheme.error,
      BudgetLevel.warning => dark ? AppColors.goldOnBand : AppColors.goldOnLight,
      BudgetLevel.normal => scheme.onSurfaceVariant,
    };

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: dark ? 0.22 : 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(categoryIcon(item.category.icon), color: tint, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.category.name,
                        style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${item.spent.format()} de ${item.limit.format()}',
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(item.ratio * 100).floor()}%',
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: color),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Mais opções',
                  onSelected: (_) => onStop(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'stop', child: Text('Parar a partir deste mês')),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.ratio.clamp(0.0, 1.0).toDouble(),
                      minHeight: 8,
                      color: color,
                      backgroundColor: dark ? AppColors.borderDark : AppColors.track,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note,
                    style: text.bodySmall?.copyWith(color: noteColor, fontWeight: FontWeight.w600),
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