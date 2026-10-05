import 'package:finly/core/di/injection.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/accounts/presentation/pages/accounts_page.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/auth/presentation/auth_messages.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/bloc/auth_event.dart';
import 'package:finly/features/auth/presentation/bloc/auth_state.dart';
import 'package:finly/features/cards/presentation/pages/cards_page.dart';
import 'package:finly/features/transactions/presentation/pages/transactions_page.dart';
import 'package:finly/features/workspaces/presentation/cubit/switch_workspace_cubit.dart';
import 'package:finly/features/workspaces/presentation/cubit/switch_workspace_state.dart';
import 'package:finly/features/workspaces/presentation/pages/onboarding_page.dart';
import 'package:finly/features/workspaces/presentation/widgets/workspace_switch_sheet.dart';
import 'package:finly/features/workspaces/presentation/workspace_messages.dart';
import 'package:finly/features/workspaces/presentation/workspace_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Temporary home after sign-in. Replaced by the dashboard (Phase 4).
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
    final text = Theme.of(context).textTheme;

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
              // Reload the user so the new active workspace shows everywhere.
              context.read<AuthBloc>().add(const UserRefreshRequested());
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

          final firstName = user.fullName.trim().split(' ').first;
          final active = user.activeWorkspace;
          final missing = user.missingWorkspaceType;
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
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Olá, $firstName', style: text.headlineMedium),
                    const SizedBox(height: 4),
                    Text(user.email, style: text.bodyMedium),
                    const SizedBox(height: 16),
                    if (active != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.account_balance_wallet_outlined),
                            label: const Text('Contas'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => AccountsPage(workspace: active),
                              ),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text('Transações'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => TransactionsPage(workspace: active),
                              ),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.credit_card),
                            label: const Text('Cartões'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CardsPage(workspace: active),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    Text('Seus workspaces', style: text.titleMedium),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final workspace in user.workspaces)
                            Card(
                              child: ListTile(
                                leading: Icon(workspaceIcon(workspace.type)),
                                title: Text(workspace.name),
                                subtitle: Text(
                                  workspace.id == user.activeWorkspaceId
                                      ? '${workspaceTypeLabel(workspace.type)} · ativo'
                                      : workspaceTypeLabel(workspace.type),
                                ),
                                trailing: workspace.id == user.activeWorkspaceId
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
                                  builder: (_) =>
                                      OnboardingPage(addingType: missing),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: state.isLoading
                          ? null
                          : () => context
                              .read<AuthBloc>()
                              .add(const SignOutRequested()),
                      child: const Text('Sair'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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