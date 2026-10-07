import 'package:finly/core/di/injection.dart';
import 'package:finly/features/alerts/domain/entities/app_alert.dart';
import 'package:finly/features/alerts/presentation/alert_texts.dart';
import 'package:finly/features/alerts/presentation/cubit/alerts_cubit.dart';
import 'package:finly/features/alerts/presentation/cubit/alerts_state.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The "Atenção" card at the top of the home screen. It shows nothing when
/// there is nothing to warn about, and it reloads whenever the dashboard does.
class DashboardAlertsCard extends StatelessWidget {
  final WorkspaceEntity workspace;

  /// Opens the budgets screen (for a budget alert).
  final VoidCallback onOpenBudgets;

  /// Opens the transactions screen (for a bill alert).
  final VoidCallback onOpenTransactions;

  const DashboardAlertsCard({
    super.key,
    required this.workspace,
    required this.onOpenBudgets,
    required this.onOpenTransactions,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AlertsCubit>(
      key: ValueKey(workspace.id),
      create: (_) => sl<AlertsCubit>()..load(workspace.id),
      child: BlocListener<DashboardCubit, DashboardState>(
        listenWhen: (previous, current) =>
            previous.status != current.status &&
            current.status == DashboardStatus.loaded,
        listener: (context, _) => context.read<AlertsCubit>().reload(),
        child: BlocBuilder<AlertsCubit, AlertsState>(
          builder: (context, state) {
            if (state.alerts.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AlertsList(
                alerts: state.alerts,
                onOpenBudgets: onOpenBudgets,
                onOpenTransactions: onOpenTransactions,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The card with the alerts: the most urgent [maxVisible], and how many more
/// there are. Each row opens the screen where it can be solved.
class AlertsList extends StatelessWidget {
  static const maxVisible = 5;

  final List<AppAlert> alerts;
  final VoidCallback onOpenBudgets;
  final VoidCallback onOpenTransactions;

  const AlertsList({
    super.key,
    required this.alerts,
    required this.onOpenBudgets,
    required this.onOpenTransactions,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final shown = alerts.take(maxVisible).toList();
    final hidden = alerts.length - shown.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Atenção', style: text.titleMedium),
            ),
            for (final alert in shown)
              InkWell(
                onTap: alert.isBudget ? onOpenBudgets : onOpenTransactions,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The icon, not only the colour, tells how urgent it is.
                      Icon(
                        alert.isUrgent ? Icons.error_outline : Icons.warning_amber,
                        color: alert.isUrgent ? scheme.error : scheme.secondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alertTitle(alert),
                              style: text.titleSmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(alertDetail(alert), style: text.bodySmall),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            if (hidden > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  hidden == 1 ? '+ 1 alerta' : '+ $hidden alertas',
                  style: text.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}