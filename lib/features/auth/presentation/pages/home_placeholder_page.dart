import 'package:finly/core/di/injection.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/accounts/presentation/pages/accounts_page.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/auth/presentation/auth_messages.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/bloc/auth_event.dart';
import 'package:finly/features/auth/presentation/bloc/auth_state.dart';
import 'package:finly/features/budgets/presentation/pages/budgets_page.dart';
import 'package:finly/features/cards/presentation/pages/cards_page.dart';
import 'package:finly/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:finly/features/dashboard/presentation/widgets/dashboard_view.dart';
import 'package:finly/features/recurring/presentation/pages/recurring_page.dart';
import 'package:finly/features/transactions/presentation/pages/transactions_page.dart';
import 'package:finly/features/workspaces/presentation/cubit/switch_workspace_cubit.dart';
import 'package:finly/features/workspaces/presentation/cubit/switch_workspace_state.dart';
import 'package:finly/features/workspaces/presentation/pages/onboarding_page.dart';
import 'package:finly/features/workspaces/presentation/widgets/workspace_switch_sheet.dart';
import 'package:finly/features/workspaces/presentation/workspace_messages.dart';
import 'package:finly/features/workspaces/presentation/workspace_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The home after sign-in: the dashboard of the active workspace, shortcuts
/// to every area, and the workspace list. (The class keeps its old name so
/// the auth gate does not change.)
class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SwitchWorkspaceCubit>(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  void _openSwitchSheet(
    BuildContext context,
    WorkspaceEntity from,
    WorkspaceEntity to,
  ) {
    // The sheet lives in its own route, so hand it the cubit explicitly.
    final cubit = context.read<SwitchWorkspaceCubit>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => WorkspaceSwitchSheet(
        from: from,
        to: to,
        onConfirm: () {
          Navigator.of(sheetContext).pop();
          cubit.switchTo(to.id);
        },
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
            if (failure != null) {
              _showMessage(context, authFailureMessage(failure));
            }
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
              _showMessage(context, 'Workspace alterado.');
            } else if (state.status == SwitchWorkspaceStatus.failure &&
                state.failure != null) {
              _showMessage(context, switchWorkspaceFailureMessage(state.failure!));
            }
          },
        ),
      ],
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final user = state.user;
          if (user == null) return const SizedBox.shrink();

          final active = user.activeWorkspace;
          final isBusiness = active?.type == WorkspaceType.business;
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

          final chipColor =
              isBusiness ? AppColors.white : Theme.of(context).colorScheme.primary;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Finly'),
              backgroundColor: isBusiness ? AppColors.deepBlue : null,
              foregroundColor: isBusiness ? AppColors.white : null,
              actions: [
                if (active != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _WorkspaceChip(
                      workspace: active,
                      color: chipColor,
                      onTap: (other == null || switching)
                          ? null
                          : () => _openSwitchSheet(context, active, other!),
                    ),
                  ),
              ],
            ),
            body: SafeArea(
              child: active == null
                  ? _HomeBody(
                      user: user,
                      active: null,
                      isLoading: state.isLoading,
                    )
                  // A new dashboard for each workspace: switching workspace
                  // changes the key, so no number of the old one stays.
                  : BlocProvider<DashboardCubit>(
                      key: ValueKey(active.id),
                      create: (_) => sl<DashboardCubit>()..load(active.id),
                      child: _HomeBody(
                        user: user,
                        active: active,
                        isLoading: state.isLoading,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  final UserEntity user;
  final WorkspaceEntity? active;
  final bool isLoading;

  const _HomeBody({
    required this.user,
    required this.active,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final workspace = active;
    final firstName = user.fullName.trim().split(' ').first;
    final missing = user.missingWorkspaceType;

    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        Text('Olá, $firstName', style: text.headlineMedium),
        const SizedBox(height: 4),
        Text(user.email, style: text.bodyMedium),
        if (workspace != null) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Contas'),
                onPressed: () =>
                    openAndRefresh(context, AccountsPage(workspace: workspace)),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Transações'),
                onPressed: () => openAndRefresh(
                  context,
                  TransactionsPage(workspace: workspace),
                ),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.credit_card),
                label: const Text('Cartões'),
                onPressed: () =>
                    openAndRefresh(context, CardsPage(workspace: workspace)),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.pie_chart_outline),
                label: const Text('Orçamentos'),
                onPressed: () =>
                    openAndRefresh(context, BudgetsPage(workspace: workspace)),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.repeat),
                label: const Text('Recorrências'),
                onPressed: () =>
                    openAndRefresh(context, RecurringPage(workspace: workspace)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DashboardView(workspace: workspace),
        ],
        const SizedBox(height: 24),
        Text('Seus workspaces', style: text.titleMedium),
        const SizedBox(height: 8),
        for (final item in user.workspaces)
          Card(
            child: ListTile(
              leading: Icon(workspaceIcon(item.type)),
              title: Text(item.name),
              subtitle: Text(
                item.id == user.activeWorkspaceId
                    ? '${workspaceTypeLabel(item.type)} · ativo'
                    : workspaceTypeLabel(item.type),
              ),
              trailing: item.id == user.activeWorkspaceId
                  ? const Icon(Icons.check_circle)
                  : null,
            ),
          ),
        if (missing != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: Text(
              missing == WorkspaceType.business
                  ? 'Adicionar workspace da empresa (CNPJ)'
                  : 'Adicionar workspace pessoal (CPF)',
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => OnboardingPage(addingType: missing),
              ),
            ),
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
    );

    // Pull down to refresh (only when there is a dashboard to refresh).
    if (workspace == null) return list;
    return RefreshIndicator(
      onRefresh: () => context.read<DashboardCubit>().reload(),
      child: list,
    );
  }
}

/// Shows which workspace is active. Tappable only when there is another one.
class _WorkspaceChip extends StatelessWidget {
  final WorkspaceEntity workspace;
  final Color color;
  final VoidCallback? onTap;

  const _WorkspaceChip({
    required this.workspace,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: color)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(workspaceIcon(workspace.type), size: 16, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    workspace.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color),
                  ),
                ),
                if (onTap != null) Icon(Icons.arrow_drop_down, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}