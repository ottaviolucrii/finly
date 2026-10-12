import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/widgets/grouped_list.dart';
import 'package:finly/core/widgets/workspace_title.dart';
import 'package:finly/features/assistant/presentation/amora.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/goals/domain/entities/goal_progress.dart';
import 'package:finly/features/goals/domain/goal_rules.dart';
import 'package:finly/features/goals/presentation/cubit/goals_cubit.dart';
import 'package:finly/features/goals/presentation/cubit/goals_state.dart';
import 'package:finly/features/goals/presentation/goal_texts.dart';
import 'package:finly/features/goals/presentation/pages/goal_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The savings goals of one workspace. The cubit is created for [workspace], so
/// it never shows the goals of another workspace.
class GoalsPage extends StatelessWidget {
  final WorkspaceEntity workspace;

  const GoalsPage({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<GoalsCubit>()..load(workspace.id),
      child: GoalsView(workspace: workspace),
    );
  }
}

/// Opens the form for a new goal (null) or to change one; true when something
/// was saved.
typedef OpenGoalForm = Future<bool?> Function(BuildContext context, GoalProgress? editing);

/// The screen itself: it uses the [GoalsCubit] above it.
class GoalsView extends StatelessWidget {
  final WorkspaceEntity workspace;

  /// Opens the form. The default is the real form; tests pass their own.
  final OpenGoalForm? openForm;

  /// "Now", to say what is overdue; tests pass a fixed date.
  final DateTime Function()? clock;

  const GoalsView({super.key, required this.workspace, this.openForm, this.clock});

  Future<void> _open(BuildContext context, GoalProgress? editing) async {
    final cubit = context.read<GoalsCubit>();
    final saved = await (openForm ?? _defaultOpen)(context, editing);
    if (saved == true) cubit.reload();
  }

  Future<bool?> _defaultOpen(BuildContext context, GoalProgress? editing) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GoalFormPage(workspace: workspace, editing: editing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusiness = workspace.type == WorkspaceType.business;

    return Scaffold(
      appBar: AppBar(
        title: WorkspaceTitle('Metas', isBusiness: isBusiness),
        backgroundColor: isBusiness ? AppColors.deepBlue : null,
        foregroundColor: isBusiness ? AppColors.white : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Nova meta'),
      ),
      body: BlocBuilder<GoalsCubit, GoalsState>(
        builder: (context, state) => _body(context, state),
      ),
    );
  }

  Widget _body(BuildContext context, GoalsState state) {
    final cubit = context.read<GoalsCubit>();

    if (state.items.isEmpty) {
      if (state.status == GoalsStatus.failure && state.failure != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(goalFailureMessage(state.failure!), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: cubit.reload, child: const Text('Tentar de novo')),
              ],
            ),
          ),
        );
      }
      if (state.status == GoalsStatus.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                'Você ainda não tem metas.\nCrie uma para acompanhar quanto já guardou.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    final now = (clock ?? DateTime.now)();
    final open = [for (final item in state.items) if (!item.achieved) item];
    final reached = [for (final item in state.items) if (item.achieved) item];

    return RefreshIndicator(
      onRefresh: cubit.reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          if (state.status == GoalsStatus.loading) const LinearProgressIndicator(minHeight: 2),
          _GoalsSummary(items: state.items),
          if (open.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionLabel('Em andamento'),
            for (final item in open) _GoalCard(item: item, today: now, onTap: () => _open(context, item)),
          ],
          if (reached.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionLabel('Alcançadas'),
            for (final item in reached) _GoalCard(item: item, today: now, onTap: () => _open(context, item)),
          ],
        ],
      ),
    );
  }
}

/// The top of the list: how much is saved in all the goals, how much is
/// still missing, and how many goals were reached.
class _GoalsSummary extends StatelessWidget {
  final List<GoalProgress> items;

  const _GoalsSummary({required this.items});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    // Amounts in other currencies are not added to the first one.
    final currency = items.first.goal.currency;
    var saved = 0, missing = 0;
    for (final item in items) {
      if (item.goal.currency != currency) continue;
      saved += item.savedCents;
      missing += item.remainingCents;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Guardado nas metas', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      Text(Money(saved, currency).format(), style: text.titleLarge),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Falta', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    Text(
                      Money(missing, currency).format(),
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.any((item) => item.achieved))
              Row(
                children: [
                  const AmoraAvatar(mood: AmoraMood.celebrating, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      goalsSummaryLine(items),
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              )
            else
              Text(goalsSummaryLine(items), style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final GoalProgress item;
  final DateTime today;
  final VoidCallback onTap;

  const _GoalCard({required this.item, required this.today, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final achieved = item.achieved;
    final overdue = item.statusAt(today) == GoalStatus.overdue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: item.percent / 100,
                      strokeWidth: 7,
                      color: achieved ? AppColors.positive : AppColors.gold,
                      backgroundColor: dark ? AppColors.borderDark : AppColors.track,
                      semanticsLabel: '${item.percent}% da meta',
                    ),
                    Center(
                      child: Text(
                        '${item.percent}%',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.goal.name,
                      style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.accountName.isNotEmpty)
                      Text(
                        '${item.accountName} · ${item.goal.currency}',
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    const SizedBox(height: 4),
                    Text(goalAmountsLine(item), style: text.bodyMedium),
                    Text(
                      goalStatusLine(item, today),
                      style: text.bodySmall?.copyWith(
                        color: overdue ? scheme.error : scheme.onSurfaceVariant,
                        fontWeight: overdue ? FontWeight.w600 : null,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
