import 'package:finly/core/di/injection.dart';
import 'package:finly/features/alerts/presentation/widgets/dashboard_alerts_card.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/budgets/presentation/pages/budgets_page.dart';
import 'package:finly/features/cards/presentation/cubit/cards_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/cards_state.dart';
import 'package:finly/features/cards/presentation/pages/cards_page.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:finly/features/dashboard/presentation/dashboard_messages.dart';
import 'package:finly/features/dashboard/presentation/widgets/dashboard_charts_card.dart';
import 'package:finly/features/dashboard/presentation/widgets/dashboard_view.dart';
import 'package:finly/features/dashboard/presentation/widgets/home/home_band.dart';
import 'package:finly/features/dashboard/presentation/widgets/home/home_cards.dart';
import 'package:finly/features/dashboard/presentation/widgets/home/home_shortcuts.dart';
import 'package:finly/features/forecast/presentation/pages/forecast_page.dart';
import 'package:finly/features/goals/domain/entities/goal_progress.dart';
import 'package:finly/features/goals/presentation/cubit/goals_cubit.dart';
import 'package:finly/features/goals/presentation/cubit/goals_state.dart';
import 'package:finly/features/goals/presentation/pages/goals_page.dart';
import 'package:finly/features/reports/presentation/pages/reports_page.dart';
import 'package:finly/features/transactions/presentation/pages/transactions_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The goal to show on Início: the first one not reached yet, or the first.
GoalProgress? goalToShow(List<GoalProgress> goals) {
  if (goals.isEmpty) return null;
  for (final goal in goals) {
    if (!goal.achieved) return goal;
  }
  return goals.first;
}

/// Início: the band with the balance, the shortcuts over its edge, and the
/// cards of the month, the credit cards, the budgets, what is coming and a
/// goal. It uses the [DashboardCubit] above it, and reads the credit cards and
/// the goals itself.
class HomeView extends StatefulWidget {
  final WorkspaceEntity workspace;

  /// "Pessoal" or "Empresa".
  final String workspaceLabel;
  final String initial;
  final VoidCallback? onSwitchWorkspace;
  final VoidCallback onProfile;
  final VoidCallback? onAdd;
  final VoidCallback? onTransfer;

  /// "Now"; tests pass a fixed date.
  final DateTime Function()? clock;

  const HomeView({
    super.key,
    required this.workspace,
    required this.workspaceLabel,
    required this.initial,
    required this.onSwitchWorkspace,
    required this.onProfile,
    required this.onAdd,
    required this.onTransfer,
    this.clock,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  /// The person can hide the values (for example in public). It lasts while
  /// the app is open.
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final workspace = widget.workspace;

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<CardsCubit>()..load(workspace.id)),
        BlocProvider(create: (_) => sl<GoalsCubit>()..load(workspace.id)),
      ],
      child: Builder(
        builder: (context) => BlocListener<DashboardCubit, DashboardState>(
          // When the dashboard reads again (pull, coming back to the tab,
          // after a change), the cards and the goals read again too.
          listenWhen: (previous, current) =>
              current.status == DashboardStatus.loading &&
              previous.status != DashboardStatus.loading,
          listener: (context, _) {
            context.read<CardsCubit>().reload();
            context.read<GoalsCubit>().reload();
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            // The band is dark: light icons in the status bar.
            value: SystemUiOverlayStyle.light,
            child: RefreshIndicator(
              onRefresh: () => context.read<DashboardCubit>().reload(),
              child: BlocBuilder<DashboardCubit, DashboardState>(
                builder: (context, state) => _list(context, state),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, DashboardState state) {
    final workspace = widget.workspace;
    final data = state.data;
    final now = (widget.clock ?? DateTime.now)();
    void open(Widget page) => openAndRefresh(context, page);

    const overlap = 56.0;

    return ListView(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // The band, with the shortcuts floating over its bottom edge.
        Stack(
          children: [
            Column(
              children: [
                HomeBand(
                  workspaceLabel: widget.workspaceLabel,
                  onSwitchWorkspace: widget.onSwitchWorkspace,
                  hidden: _hidden,
                  onToggleHidden: () => setState(() => _hidden = !_hidden),
                  initial: widget.initial,
                  onProfile: widget.onProfile,
                  balances: data?.balances,
                  hasAccounts: data?.hasAccounts ?? true,
                  bottomSpace: overlap + 16,
                ),
                const SizedBox(height: 60),
              ],
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 0,
              child: HomeShortcuts(
                onAdd: widget.onAdd,
                onTransfer: widget.onTransfer,
                onPayInvoice: () => open(CardsPage(workspace: workspace, preferDue: true)),
                onForecast: () => open(ForecastPage(workspace: workspace)),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashboardAlertsCard(
                workspace: workspace,
                onOpenBudgets: () => open(BudgetsPage(workspace: workspace)),
                onOpenTransactions: () => open(TransactionsPage(workspace: workspace)),
              ),
              if (data == null)
                _loadingOrError(context, state)
              else ...[
                HomeMonthCard(
                  month: data.month,
                  flow: data.flows.isEmpty ? null : data.flows.first,
                  hidden: _hidden,
                  onOpenReport: () => open(ReportsPage(workspace: workspace)),
                ),
                BlocBuilder<CardsCubit, CardsState>(
                  builder: (context, cards) => cards.cards.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: HomeCreditCardsCard(
                            cards: cards.cards,
                            onOpen: () => open(CardsPage(workspace: workspace)),
                          ),
                        ),
                ),
                if (data.budgets.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: HomeBudgetsCard(
                      budgets: data.budgets,
                      onOpen: () => open(BudgetsPage(workspace: workspace)),
                    ),
                  ),
                if (data.upcoming.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: HomeUpcomingCard(
                      items: data.upcoming,
                      now: now,
                      onOpen: () => open(TransactionsPage(workspace: workspace)),
                    ),
                  ),
                BlocBuilder<GoalsCubit, GoalsState>(
                  builder: (context, goals) {
                    final goal = goalToShow(goals.items);
                    if (goal == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: HomeGoalCard(
                        goal: goal,
                        today: now,
                        onOpen: () => open(GoalsPage(workspace: workspace)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                DashboardChartsCard(workspace: workspace),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _loadingOrError(BuildContext context, DashboardState state) {
    final failure = state.failure;
    if (state.status == DashboardStatus.failure && failure != null) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(dashboardFailureMessage(failure), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.read<DashboardCubit>().reload(),
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
