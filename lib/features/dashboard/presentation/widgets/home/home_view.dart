import 'package:finly/core/di/injection.dart';
import 'package:finly/features/accounts/presentation/cubit/accounts_cubit.dart';
import 'package:finly/features/accounts/presentation/cubit/accounts_state.dart';
import 'package:finly/features/accounts/presentation/pages/account_form_page.dart';
import 'package:finly/features/accounts/presentation/pages/accounts_page.dart';
import 'package:finly/features/alerts/presentation/widgets/dashboard_alerts_card.dart';
import 'package:finly/features/assistant/presentation/amora_shortcuts.dart';
import 'package:finly/features/assistant/presentation/amora_tips.dart';
import 'package:finly/features/assistant/presentation/getting_started.dart';
import 'package:finly/features/assistant/presentation/widgets/amora_helper.dart';
import 'package:finly/features/assistant/presentation/widgets/amora_sheet.dart';
import 'package:finly/features/assistant/presentation/widgets/getting_started_card.dart';
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
import 'package:finly/features/dashboard/presentation/widgets/home/home_accounts.dart';
import 'package:finly/features/dashboard/presentation/widgets/home/home_band.dart';
import 'package:finly/features/dashboard/presentation/widgets/home/home_cards.dart';
import 'package:finly/features/dashboard/presentation/widgets/home/home_shortcuts.dart';
import 'package:finly/features/forecast/presentation/pages/forecast_page.dart';
import 'package:finly/features/goals/domain/entities/goal_progress.dart';
import 'package:finly/features/goals/presentation/cubit/goals_cubit.dart';
import 'package:finly/features/goals/presentation/cubit/goals_state.dart';
import 'package:finly/features/goals/presentation/pages/goals_page.dart';
import 'package:finly/features/recurring/presentation/pages/recurring_page.dart';
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

  /// Where the choices about "Primeiros passos" are kept.
  final GettingStartedStore gettingStarted;

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
    this.gettingStarted = const PrefsGettingStartedStore(),
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
        BlocProvider(create: (_) => sl<AccountsCubit>()..load(workspace.id)),
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
            context.read<AccountsCubit>().reload();
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            // The band is dark: light icons in the status bar.
            value: SystemUiOverlayStyle.light,
            child: Stack(
              children: [
                Positioned.fill(
                  child: RefreshIndicator(
                    onRefresh: () => context.read<DashboardCubit>().reload(),
                    child: BlocBuilder<DashboardCubit, DashboardState>(
                      builder: (context, state) => _list(context, state),
                    ),
                  ),
                ),
                // Amora, the helper: a small button in the corner; Início
                // itself stays as it is.
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: BlocBuilder<DashboardCubit, DashboardState>(
                    buildWhen: (previous, current) => previous.data != current.data,
                    builder: (context, state) {
                      final tip = amoraTipFor(
                        budgets: state.data?.budgets ?? const [],
                        upcoming: state.data?.upcoming ?? const [],
                        today: (widget.clock ?? DateTime.now)(),
                      );
                      return AmoraHelper(
                        tip: tip,
                        onOpen: () => showAmoraSheet(
                          context,
                          tip: tip,
                          onWrite: () => widget.onAdd?.call(),
                          shortcuts: _amoraShortcuts(context),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The places of the app Amora can take the person to.
  List<AmoraShortcut> _amoraShortcuts(BuildContext context) {
    final workspace = widget.workspace;
    void open(Widget page) => openAndRefresh(context, page);
    return [
      if (widget.onAdd != null)
        AmoraShortcut(
          title: 'Novo lançamento',
          hint: 'Despesa ou receita, ou escreva como você falaria',
          icon: Icons.add_circle_outline,
          keywords: const ['lancar', 'lançamento', 'gasto', 'gastei', 'despesa', 'receita', 'adicionar', 'registrar'],
          onOpen: widget.onAdd!,
        ),
      if (widget.onTransfer != null)
        AmoraShortcut(
          title: 'Transferir',
          hint: 'Entre suas contas',
          icon: Icons.swap_horiz,
          keywords: const ['transferencia', 'mover', 'passar dinheiro', 'pix entre contas'],
          onOpen: widget.onTransfer!,
        ),
      AmoraShortcut(
        title: 'Pagar fatura',
        hint: 'A fatura do cartão que está para pagar',
        icon: Icons.receipt_long_outlined,
        keywords: const ['fatura', 'pagar', 'pago', 'pagamento', 'cartao', 'vencimento'],
        onOpen: () => open(CardsPage(workspace: workspace, preferDue: true)),
      ),
      AmoraShortcut(
        title: 'Cartões',
        hint: 'Limite, faturas e compras parceladas',
        icon: Icons.credit_card,
        keywords: const ['cartao', 'credito', 'limite', 'parcelado', 'parcela', 'novo cartao'],
        onOpen: () => open(CardsPage(workspace: workspace)),
      ),
      AmoraShortcut(
        title: 'Extrato',
        hint: 'Todos os lançamentos, mês a mês',
        icon: Icons.receipt_outlined,
        keywords: const ['extrato', 'lancamentos', 'transacoes', 'historico', 'buscar', 'gastos', 'entradas', 'saidas'],
        onOpen: () => open(TransactionsPage(workspace: workspace)),
      ),
      AmoraShortcut(
        title: 'Contas',
        hint: 'Saldos das suas contas',
        icon: Icons.account_balance_outlined,
        keywords: const ['conta', 'banco', 'saldo', 'arquivar'],
        onOpen: () => open(AccountsPage(workspace: workspace)),
      ),
      AmoraShortcut(
        title: 'Nova conta',
        hint: 'Cadastrar um banco ou a carteira',
        icon: Icons.add_card_outlined,
        keywords: const ['criar conta', 'cadastrar', 'banco novo', 'carteira'],
        onOpen: () => open(AccountFormPage(workspaceId: workspace.id)),
      ),
      AmoraShortcut(
        title: 'Orçamentos',
        hint: 'Limites por categoria',
        icon: Icons.donut_large_outlined,
        keywords: const ['orcamento', 'limite', 'gastar menos', 'economizar', 'categoria'],
        onOpen: () => open(BudgetsPage(workspace: workspace)),
      ),
      AmoraShortcut(
        title: 'Metas',
        hint: 'Guardar dinheiro para um objetivo',
        icon: Icons.flag_outlined,
        keywords: const ['meta', 'objetivo', 'guardar', 'poupar', 'reserva', 'economia'],
        onOpen: () => open(GoalsPage(workspace: workspace)),
      ),
      AmoraShortcut(
        title: 'Previsão de saldo',
        hint: 'Como fica o saldo nos próximos dias',
        icon: Icons.show_chart,
        keywords: const ['previsao', 'futuro', 'saldo previsto', 'proximos', 'negativo'],
        onOpen: () => open(ForecastPage(workspace: workspace)),
      ),
      AmoraShortcut(
        title: 'Recorrências',
        hint: 'Aluguel, salário, assinaturas',
        icon: Icons.repeat,
        keywords: const ['recorrente', 'mensal', 'aluguel', 'salario', 'assinatura', 'repetir', 'todo mes'],
        onOpen: () => open(RecurringPage(workspace: workspace)),
      ),
      AmoraShortcut(
        title: 'Primeiros passos',
        hint: 'O guia da Amora para começar',
        icon: Icons.checklist,
        keywords: const ['guia', 'comecar', 'tutorial', 'ajuda', 'primeiros passos', 'inicio'],
        onOpen: () => widget.gettingStarted.setHidden(workspace.id, false),
      ),
      AmoraShortcut(
        title: 'Relatório',
        hint: 'Gráficos e exportar em PDF ou CSV',
        icon: Icons.bar_chart,
        keywords: const ['relatorio', 'exportar', 'pdf', 'csv', 'grafico', 'resumo'],
        onOpen: () => open(ReportsPage(workspace: workspace)),
      ),
    ];
  }

  Widget _list(BuildContext context, DashboardState state) {
    final workspace = widget.workspace;
    final data = state.data;
    final now = (widget.clock ?? DateTime.now)();
    void open(Widget page) => openAndRefresh(context, page);

    const overlap = 56.0;

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
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
                  onOpenAccounts: () => open(AccountsPage(workspace: workspace)),
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
              // "Primeiros passos": Amora's guide for a new workspace.
              Builder(builder: (context) {
                final accounts = context.watch<AccountsCubit>().state;
                final cards = context.watch<CardsCubit>().state;
                final goals = context.watch<GoalsCubit>().state;
                final flows = data?.flows ?? const [];
                final ready = data != null &&
                    accounts.status == AccountsStatus.loaded &&
                    cards.status == CardsStatus.loaded &&
                    goals.status == GoalsStatus.loaded;
                return GettingStartedCard(
                  workspaceId: workspace.id,
                  ready: ready,
                  store: widget.gettingStarted,
                  done: startStepsDone(
                    hasAccount: homeAccounts(accounts.accounts).isNotEmpty,
                    hasTransaction: (data?.upcoming.isNotEmpty ?? false) ||
                        flows.any((f) =>
                            f.incomePostedCents + f.incomePendingCents + f.expensePostedCents + f.expensePendingCents > 0),
                    hasCard: cards.cards.isNotEmpty,
                    hasBudget: data?.budgets.isNotEmpty ?? false,
                    hasGoal: goals.items.isNotEmpty,
                  ),
                  onOpen: (step) {
                    switch (step) {
                      case StartStep.account:
                        open(AccountFormPage(workspaceId: workspace.id));
                      case StartStep.transaction:
                        widget.onAdd?.call();
                      case StartStep.card:
                        open(CardsPage(workspace: workspace));
                      case StartStep.budget:
                        open(BudgetsPage(workspace: workspace));
                      case StartStep.goal:
                        open(GoalsPage(workspace: workspace));
                    }
                  },
                );
              }),
              const SizedBox(height: 20),
              BlocBuilder<AccountsCubit, AccountsState>(
                // When the accounts cannot be read, the row steps aside (the
                // balance above still opens Contas).
                builder: (context, accounts) => accounts.status == AccountsStatus.failure && accounts.accounts.isEmpty
                    ? const SizedBox.shrink()
                    : HomeAccountsRow(
                  accounts: accounts.status == AccountsStatus.loaded || accounts.accounts.isNotEmpty
                      ? homeAccounts(accounts.accounts)
                      : null,
                  hidden: _hidden,
                  onOpenAccount: (account) => open(TransactionsPage(workspace: workspace, accountId: account.id)),
                  onSeeAll: () => open(AccountsPage(workspace: workspace)),
                  onNewAccount: () => open(AccountFormPage(workspaceId: workspace.id)),
                    ),
              ),
              const SizedBox(height: 20),
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
