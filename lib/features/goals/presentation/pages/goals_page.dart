import 'package:finly/core/di/injection.dart';
import 'package:finly/core/theme/app_colors.dart';
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
        title: const Text('Metas'),
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
    final text = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: cubit.reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (state.status == GoalsStatus.loading) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(goalsSummaryLine(state.items), style: text.bodyMedium),
          ),
          for (final item in state.items)
            _GoalCard(item: item, today: now, onTap: () => _open(context, item)),
        ],
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
    final achieved = item.achieved;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    achieved ? Icons.flag : Icons.flag_outlined,
                    color: achieved ? scheme.secondary : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.goal.name,
                      style: text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('${item.percent}%', style: text.titleMedium),
                ],
              ),
              if (item.accountName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 32, top: 2),
                  child: Text(
                    '${item.accountName} · ${item.goal.currency}',
                    style: text.bodySmall,
                  ),
                ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.percent / 100,
                  minHeight: 8,
                  color: achieved ? scheme.secondary : null,
                  semanticsLabel: '${item.percent}% da meta',
                ),
              ),
              const SizedBox(height: 8),
              Text(goalAmountsLine(item), style: text.bodyMedium),
              const SizedBox(height: 2),
              Text(
                goalStatusLine(item, today),
                style: text.bodySmall?.copyWith(
                  color: item.statusAt(today) == GoalStatus.overdue ? scheme.error : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
