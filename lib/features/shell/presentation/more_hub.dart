import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/widgets/grouped_list.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/workspaces/presentation/workspace_style.dart';
import 'package:flutter/material.dart';

/// The places the Mais tab leads to.
enum MoreDestination { accounts, cards, categories, reports, history, settings }

/// The first letter of a name, for the avatar ("?" when there is none).
String initialOf(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
}

/// The Mais tab: who is signed in, the switch between the personal and the
/// company workspace, and the rest of the app in grouped lists.
class MoreHub extends StatelessWidget {
  final UserEntity user;

  /// True while a switch of workspace is going on (the switch is disabled).
  final bool switching;

  /// True while signing out (the button is disabled).
  final bool signingOut;

  final ValueChanged<MoreDestination> onOpen;

  /// Asks to make [workspace] the active one (a confirmation may come first).
  final ValueChanged<WorkspaceEntity> onSwitchTo;

  /// Adds the workspace the user does not have yet.
  final ValueChanged<WorkspaceType> onAddWorkspace;

  final VoidCallback onSignOut;

  const MoreHub({
    super.key,
    required this.user,
    required this.switching,
    required this.signingOut,
    required this.onOpen,
    required this.onSwitchTo,
    required this.onAddWorkspace,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final missing = user.missingWorkspaceType;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          const TabHeader(kicker: 'Sua conta', title: 'Mais'),
          const SizedBox(height: 24),
          _ProfileCard(
            user: user,
            switching: switching,
            onSwitchTo: onSwitchTo,
            missing: missing,
            onAddWorkspace: onAddWorkspace,
          ),
          const SizedBox(height: 24),
          GroupedSection(
            label: 'Dinheiro',
            items: [
              GroupedItem(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Contas',
                onTap: () => onOpen(MoreDestination.accounts),
              ),
              GroupedItem(
                icon: Icons.credit_card,
                title: 'Cartões',
                onTap: () => onOpen(MoreDestination.cards),
              ),
              GroupedItem(
                icon: Icons.sell_outlined,
                title: 'Categorias',
                onTap: () => onOpen(MoreDestination.categories),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GroupedSection(
            label: 'Análises',
            items: [
              GroupedItem(
                icon: Icons.bar_chart,
                title: 'Relatórios',
                subtitle: 'O mês em números, em PDF ou CSV',
                onTap: () => onOpen(MoreDestination.reports),
              ),
              GroupedItem(
                icon: Icons.history,
                title: 'Histórico de alterações',
                onTap: () => onOpen(MoreDestination.history),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GroupedSection(
            label: 'Conta e privacidade',
            items: [
              GroupedItem(
                icon: Icons.settings_outlined,
                title: 'Configurações',
                subtitle: 'Aparência, notificações, bloqueio e privacidade',
                onTap: () => onOpen(MoreDestination.settings),
              ),
            ],
          ),
          const SizedBox(height: 24),
          GroupedSection(
            items: [
              GroupedItem(
                icon: Icons.logout,
                title: 'Sair',
                danger: true,
                onTap: signingOut ? null : onSignOut,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserEntity user;
  final bool switching;
  final ValueChanged<WorkspaceEntity> onSwitchTo;
  final WorkspaceType? missing;
  final ValueChanged<WorkspaceType> onAddWorkspace;

  const _ProfileCard({
    required this.user,
    required this.switching,
    required this.onSwitchTo,
    required this.missing,
    required this.onAddWorkspace,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final add = missing;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.midnight,
                  child: Text(
                    initialOf(user.fullName),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: text.titleLarge?.copyWith(fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.email,
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (user.workspaces.length > 1)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: dark ? AppColors.canvasDark : AppColors.hairline,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    for (final workspace in user.workspaces)
                      Expanded(
                        child: _WorkspaceSegment(
                          workspace: workspace,
                          active: workspace.id == user.activeWorkspaceId,
                          onTap: switching || workspace.id == user.activeWorkspaceId
                              ? null
                              : () => onSwitchTo(workspace),
                        ),
                      ),
                  ],
                ),
              )
            else if (add != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(
                  add == WorkspaceType.business
                      ? 'Adicionar a empresa (CNPJ)'
                      : 'Adicionar o pessoal (CPF)',
                ),
                onPressed: () => onAddWorkspace(add),
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceSegment extends StatelessWidget {
  final WorkspaceEntity workspace;
  final bool active;
  final VoidCallback? onTap;

  const _WorkspaceSegment({
    required this.workspace,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: active,
      label: workspaceTypeLabel(workspace.type),
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: active ? scheme.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        elevation: active ? 1 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(
                workspaceTypeLabel(workspace.type),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
