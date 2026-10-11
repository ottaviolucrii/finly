import 'package:finly/core/di/injection.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/budgets/presentation/cubit/budgets_cubit.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:finly/features/forecast/presentation/cubit/forecast_cubit.dart';
import 'package:finly/features/goals/presentation/cubit/goals_cubit.dart';
import 'package:finly/features/shell/presentation/plan_hub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Planejar tab with its data: the forecast, the budgets and the goals of
/// [workspace]. They read again after a page it opened closes, on pull to
/// refresh, and whenever the dashboard reads again (after a new transaction).
class PlanTab extends StatelessWidget {
  final WorkspaceEntity workspace;

  /// Opens a place; the future ends when the person comes back.
  final Future<void> Function(PlanDestination destination) onOpen;

  const PlanTab({super.key, required this.workspace, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<ForecastCubit>()..load(workspace.id)),
        BlocProvider(create: (_) => sl<BudgetsCubit>()..load(workspace.id)),
        BlocProvider(create: (_) => sl<GoalsCubit>()..load(workspace.id)),
      ],
      child: Builder(builder: (context) {
        Future<void> reloadAll() async {
          await Future.wait([
            context.read<ForecastCubit>().reload(),
            context.read<BudgetsCubit>().reload(),
            context.read<GoalsCubit>().reload(),
          ]);
        }

        return BlocListener<DashboardCubit, DashboardState>(
          listenWhen: (previous, current) =>
              current.status == DashboardStatus.loading && previous.status != DashboardStatus.loading,
          listener: (context, _) => reloadAll(),
          child: Builder(builder: (context) {
            final forecast = context.watch<ForecastCubit>().state;
            final budgets = context.watch<BudgetsCubit>().state;
            final goals = context.watch<GoalsCubit>().state;

            return PlanHub(
              isBusiness: workspace.type == WorkspaceType.business,
              forecast: forecast,
              budgets: budgets,
              goals: goals,
              onRefresh: reloadAll,
              onOpen: (destination) async {
                await onOpen(destination);
                await reloadAll();
              },
            );
          }),
        );
      }),
    );
  }
}
