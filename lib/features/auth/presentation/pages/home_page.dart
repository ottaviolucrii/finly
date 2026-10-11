import 'package:finly/core/di/injection.dart';
import 'package:finly/core/widgets/finly_tab_bar.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/usecases/get_accounts_use_case.dart';
import 'package:finly/features/accounts/presentation/pages/accounts_page.dart';
import 'package:finly/features/audit/presentation/pages/audit_history_page.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/auth/presentation/auth_messages.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/bloc/auth_event.dart';
import 'package:finly/features/auth/presentation/bloc/auth_state.dart';
import 'package:finly/features/budgets/presentation/pages/budgets_page.dart';
import 'package:finly/features/cards/presentation/pages/cards_page.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/usecases/get_all_categories_use_case.dart';
import 'package:finly/features/categories/presentation/pages/categories_page.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:finly/features/dashboard/presentation/widgets/dashboard_view.dart';
import 'package:finly/features/dashboard/presentation/widgets/home/home_view.dart';
import 'package:finly/features/forecast/presentation/pages/forecast_page.dart';
import 'package:finly/features/goals/presentation/pages/goals_page.dart';
import 'package:finly/features/lock/presentation/cubit/app_lock_cubit.dart';
import 'package:finly/features/recurring/presentation/pages/recurring_page.dart';
import 'package:finly/features/reports/presentation/pages/reports_page.dart';
import 'package:finly/features/settings/presentation/pages/settings_page.dart';
import 'package:finly/features/shell/presentation/more_hub.dart';
import 'package:finly/features/shell/presentation/plan_hub.dart';
import 'package:finly/features/shell/presentation/plan_tab.dart';
import 'package:finly/features/tax_reserve/presentation/pages/tax_reserve_page.dart';
import 'package:finly/features/transactions/presentation/pages/transaction_form_page.dart';
import 'package:finly/features/transactions/presentation/pages/transactions_page.dart';
import 'package:finly/features/transfers/presentation/pages/transfer_form_page.dart';
import 'package:finly/features/workspaces/presentation/cubit/switch_workspace_cubit.dart';
import 'package:finly/features/workspaces/presentation/cubit/switch_workspace_state.dart';
import 'package:finly/features/workspaces/presentation/pages/onboarding_page.dart';
import 'package:finly/features/workspaces/presentation/widgets/workspace_switch_sheet.dart';
import 'package:finly/features/workspaces/presentation/workspace_messages.dart';
import 'package:finly/features/yield_simulator/presentation/pages/yield_simulator_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The app after sign-in: four tabs (Início, Extrato, Planejar, Mais) and a
/// round "+" in the middle of the bar that adds a transaction.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SwitchWorkspaceCubit>(),
      child: const _HomeShell(),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  FinlyTab _tab = FinlyTab.home;

  /// The tabs opened at least once. A tab is built the first time it is
  /// opened, so the app does not load every screen when it starts.
  final Set<FinlyTab> _opened = {FinlyTab.home};

  /// Goes up when a transaction is added from the "+", so the Extrato tab
  /// (if it was already open) reads its list again.
  int _statementVersion = 0;

  /// True while the "+" gets the accounts and categories for the form.
  bool _adding = false;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _select(FinlyTab tab, DashboardCubit dashboard) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _opened.add(tab);
    });
    // Coming back to Início: something may have changed in another tab.
    if (tab == FinlyTab.home) dashboard.reload();
  }

  void _openSwitchSheet(
    BuildContext context,
    WorkspaceEntity from,
    WorkspaceEntity to,
  ) {
    // The sheet lives in its own route, so hand it what it needs explicitly.
    final cubit = context.read<SwitchWorkspaceCubit>();
    final lock = context.read<AppLockCubit>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => WorkspaceSwitchSheet(
        from: from,
        to: to,
        level: lock.state.settings.switchProtection,
        deviceSupported: lock.state.deviceSupported,
        onConfirm: () {
          Navigator.of(sheetContext).pop();
          cubit.switchTo(to.id);
        },
        onConfirmWithDevice: () =>
            lock.confirmWithDevice('Confirme para trocar de workspace'),
        onCheckPassword: lock.checkPassword,
      ),
    );
  }

  /// The "+": gets what the form needs and opens it.
  Future<void> _quickAdd(
    BuildContext context,
    WorkspaceEntity workspace,
    DashboardCubit dashboard,
  ) async {
    if (_adding) return;
    setState(() => _adding = true);

    final navigator = Navigator.of(context);
    final accountsResult = await sl<GetAccountsUseCase>()(workspace.id);
    final categoriesResult = await sl<GetAllCategoriesUseCase>()(workspace.id);
    if (!mounted) return;
    setState(() => _adding = false);

    final accounts = accountsResult.fold<List<AccountEntity>?>((_) => null, (list) => list);
    final categories =
        categoriesResult.fold<List<CategoryEntity>?>((_) => null, (list) => list);
    if (accounts == null || categories == null) {
      _showMessage('Não foi possível abrir o lançamento. Tente de novo.');
      return;
    }
    if (accounts.isEmpty) {
      _showMessage('Crie uma conta antes de lançar transações.');
      return;
    }

    final created = await navigator.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TransactionFormPage(
          workspaceId: workspace.id,
          accounts: accounts,
          categories: categories,
        ),
      ),
    );
    if (created == true && mounted) {
      setState(() => _statementVersion++);
      await dashboard.reload();
    }
  }

  /// The "Transferir" shortcut: gets the accounts and opens the form.
  Future<void> _openTransfer(
    BuildContext context,
    WorkspaceEntity workspace,
    WorkspaceEntity? other,
    DashboardCubit dashboard,
  ) async {
    if (_adding) return;
    setState(() => _adding = true);

    final navigator = Navigator.of(context);
    final result = await sl<GetAccountsUseCase>()(workspace.id);
    if (!mounted) return;
    setState(() => _adding = false);

    final accounts = result.fold<List<AccountEntity>?>((_) => null, (list) => list);
    if (accounts == null) {
      _showMessage('Não foi possível abrir a transferência. Tente de novo.');
      return;
    }
    if (accounts.isEmpty) {
      _showMessage('Crie uma conta antes de transferir.');
      return;
    }

    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TransferFormPage(
          workspace: workspace,
          accounts: accounts,
          otherWorkspace: other,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _statementVersion++);
    await dashboard.reload();
  }

  Widget _pageForPlan(PlanDestination destination, WorkspaceEntity workspace) {
    return switch (destination) {
      PlanDestination.budgets => BudgetsPage(workspace: workspace),
      PlanDestination.goals => GoalsPage(workspace: workspace),
      PlanDestination.forecast => ForecastPage(workspace: workspace),
      PlanDestination.recurring => RecurringPage(workspace: workspace),
      PlanDestination.simulator => const YieldSimulatorPage(),
      PlanDestination.taxReserve => TaxReservePage(workspace: workspace),
    };
  }

  Widget _pageForMore(MoreDestination destination, UserEntity user, WorkspaceEntity workspace) {
    return switch (destination) {
      MoreDestination.accounts => AccountsPage(workspace: workspace),
      MoreDestination.cards => CardsPage(workspace: workspace),
      MoreDestination.categories => CategoriesPage(workspace: workspace),
      MoreDestination.reports => ReportsPage(workspace: workspace),
      MoreDestination.history => AuditHistoryPage(workspace: workspace),
      MoreDestination.settings => SettingsPage(user: user),
    };
  }

  void _addWorkspace(WorkspaceType type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => OnboardingPage(addingType: type)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              previous.status != current.status &&
              current.status == AuthStatus.failure,
          listener: (context, state) {
            final failure = state.failure;
            if (failure != null) _showMessage(authFailureMessage(failure));
          },
        ),
        BlocListener<SwitchWorkspaceCubit, SwitchWorkspaceState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status == SwitchWorkspaceStatus.success) {
              // Show the new active workspace everywhere.
              final switched = state.user;
              context.read<AuthBloc>().add(
                    switched != null
                        ? UserReplaced(switched)
                        : const UserRefreshRequested(),
                  );
              _showMessage('Workspace alterado.');
            } else if (state.status == SwitchWorkspaceStatus.failure &&
                state.failure != null) {
              _showMessage(switchWorkspaceFailureMessage(state.failure!));
            }
          },
        ),
      ],
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final user = state.user;
          if (user == null) return const SizedBox.shrink();

          final active = user.activeWorkspace;
          if (active == null) {
            return _NoWorkspaceYet(
              user: user,
              isLoading: state.isLoading,
              onAdd: _addWorkspace,
            );
          }

          // A new dashboard for each workspace: switching workspace changes
          // the key, so no number of the old one stays.
          return BlocProvider<DashboardCubit>(
            key: ValueKey(active.id),
            create: (_) => sl<DashboardCubit>()..load(active.id),
            child: Builder(
              builder: (context) => _buildShell(context, user, active, state.isLoading),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShell(
    BuildContext context,
    UserEntity user,
    WorkspaceEntity active,
    bool isLoading,
  ) {
    final dashboard = context.read<DashboardCubit>();
    final switching = context.watch<SwitchWorkspaceCubit>().state.status ==
        SwitchWorkspaceStatus.switching;

    // The other workspace, when the user has two.
    WorkspaceEntity? other;
    for (final workspace in user.workspaces) {
      if (workspace.id != user.activeWorkspaceId) {
        other = workspace;
        break;
      }
    }

    Widget tab(FinlyTab which) {
      if (!_opened.contains(which)) return const SizedBox.shrink();
      return switch (which) {
        FinlyTab.home => HomeView(
            workspace: active,
            workspaceLabel: active.type == WorkspaceType.business ? 'Empresa' : 'Pessoal',
            initial: initialOf(user.fullName),
            onSwitchWorkspace: (other == null || switching)
                ? null
                : () => _openSwitchSheet(context, active, other!),
            onProfile: () => _select(FinlyTab.more, dashboard),
            onAdd: _adding ? null : () => _quickAdd(context, active, dashboard),
            onTransfer: _adding ? null : () => _openTransfer(context, active, other, dashboard),
          ),
        FinlyTab.statement => KeyedSubtree(
            key: ValueKey('statement-$_statementVersion'),
            child: TransactionsPage(workspace: active),
          ),
        FinlyTab.plan => PlanTab(
            workspace: active,
            onOpen: (destination) =>
                openAndRefresh(context, _pageForPlan(destination, active)),
          ),
        FinlyTab.more => MoreHub(
            user: user,
            switching: switching,
            signingOut: isLoading,
            onOpen: (destination) =>
                openAndRefresh(context, _pageForMore(destination, user, active)),
            onSwitchTo: (target) => _openSwitchSheet(context, active, target),
            onAddWorkspace: _addWorkspace,
            onSignOut: () => context.read<AuthBloc>().add(const SignOutRequested()),
          ),
      };
    }

    return PopScope(
      // Back on another tab goes to Início first; on Início it leaves the app.
      canPop: _tab == FinlyTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(FinlyTab.home, dashboard);
      },
      child: Scaffold(
        body: IndexedStack(
          index: FinlyTab.values.indexOf(_tab),
          children: [for (final which in FinlyTab.values) tab(which)],
        ),
        bottomNavigationBar: FinlyTabBar(
          current: _tab,
          onSelect: (which) => _select(which, dashboard),
          onAdd: _adding ? null : () => _quickAdd(context, active, dashboard),
        ),
      ),
    );
  }
}

/// Shown while the user has no workspace yet (right after creating the
/// account, before onboarding finished).
class _NoWorkspaceYet extends StatelessWidget {
  final UserEntity user;
  final bool isLoading;
  final ValueChanged<WorkspaceType> onAdd;

  const _NoWorkspaceYet({
    required this.user,
    required this.isLoading,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final firstName = user.fullName.trim().split(' ').first;
    final missing = user.missingWorkspaceType;

    return Scaffold(
      appBar: AppBar(title: const Text('Finly')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Olá, $firstName', style: text.headlineMedium),
          const SizedBox(height: 4),
          Text(user.email, style: text.bodyMedium),
          if (missing != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: Text(
                missing == WorkspaceType.business
                    ? 'Adicionar workspace da empresa (CNPJ)'
                    : 'Adicionar workspace pessoal (CPF)',
              ),
              onPressed: () => onAdd(missing),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: isLoading
                ? null
                : () => context.read<AuthBloc>().add(const SignOutRequested()),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}
