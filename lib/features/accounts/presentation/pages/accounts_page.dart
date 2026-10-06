import 'package:finly/core/di/injection.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/presentation/account_messages.dart';
import 'package:finly/features/accounts/presentation/account_style.dart';
import 'package:finly/features/accounts/presentation/cubit/accounts_cubit.dart';
import 'package:finly/features/accounts/presentation/cubit/accounts_state.dart';
import 'package:finly/features/accounts/presentation/pages/account_form_page.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/dashboard/domain/dashboard_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Accounts of one workspace. The cubit is created for [workspace], so it
/// never shows accounts of another workspace.
class AccountsPage extends StatelessWidget {
  final WorkspaceEntity workspace;

  const AccountsPage({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AccountsCubit>()..load(workspace.id),
      child: _AccountsView(workspace: workspace),
    );
  }
}

class _AccountsView extends StatelessWidget {
  final WorkspaceEntity workspace;

  const _AccountsView({required this.workspace});

  Future<void> _openForm(BuildContext context) async {
    final cubit = context.read<AccountsCubit>();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AccountFormPage(workspaceId: workspace.id),
      ),
    );
    if (created == true) await cubit.reload();
  }

  Future<void> _confirmArchive(
    BuildContext context,
    AccountEntity account,
  ) async {
    final cubit = context.read<AccountsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Arquivar conta?'),
        content: Text(
          'A conta "${account.name}" sai da lista, mas o histórico é mantido.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Arquivar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.archive(account.id);
  }

  @override
  Widget build(BuildContext context) {
    final isBusiness = workspace.type == WorkspaceType.business;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contas'),
        backgroundColor: isBusiness ? AppColors.deepBlue : null,
        foregroundColor: isBusiness ? AppColors.white : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova conta'),
      ),
      body: BlocConsumer<AccountsCubit, AccountsState>(
        listenWhen: (previous, current) =>
            current.actionFailure != null &&
            previous.actionFailure != current.actionFailure,
        listener: (context, state) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(accountFailureMessage(state.actionFailure!))),
            );
        },
        builder: (context, state) {
          if (state.status == AccountsStatus.failure) {
            return _ErrorView(
              message: accountFailureMessage(state.failure!),
              onRetry: () => context.read<AccountsCubit>().reload(),
            );
          }
          if (state.status != AccountsStatus.loaded && state.accounts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.accounts.isEmpty) return const _EmptyView();

          return _AccountList(
            accounts: state.accounts,
            onArchive: (account) => _confirmArchive(context, account),
          );
        },
      ),
    );
  }
}

class _AccountList extends StatelessWidget {
  final List<AccountEntity> accounts;
  final void Function(AccountEntity account) onArchive;

  const _AccountList({required this.accounts, required this.onArchive});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // Credit cards are not part of the total (it is what you have); what is
    // owed on them is shown on its own line, like on the dashboard.
    final totals = totalsByCurrency(accounts);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saldo total', style: text.titleMedium),
                const SizedBox(height: 8),
                for (final total in totals) ...[
                  Text(
                    total.posted.format(),
                    style: text.headlineSmall?.copyWith(
                      color: total.posted.isNegative ? scheme.error : null,
                    ),
                  ),
                  if (total.cardDebtCents > 0)
                    Text(
                      'Cartões em uso: ${total.cardDebt.format()}',
                      style: text.bodySmall,
                    ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final account in accounts)
          _AccountTile(account: account, onArchive: () => onArchive(account)),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  final AccountEntity account;
  final VoidCallback onArchive;

  const _AccountTile({required this.account, required this.onArchive});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final balance = account.postedBalance;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(accountTypeIcon(account.type), color: scheme.primary),
            ),
            const SizedBox(width: 16),
            // The name gets the full width; the balance sits below it.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: text.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(accountTypeLabel(account.type), style: text.bodySmall),
                  const SizedBox(height: 6),
                  Text(
                    balance.format(),
                    style: text.titleLarge?.copyWith(
                      color: balance.isNegative ? scheme.error : null,
                    ),
                  ),
                  if (account.hasPendingEffect)
                    Text(
                      'Previsto: ${account.projectedBalance.format()}',
                      style: text.bodySmall,
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Mais opções',
              onSelected: (_) => onArchive(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'archive', child: Text('Arquivar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 56),
            const SizedBox(height: 16),
            Text('Nenhuma conta ainda', style: text.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Toque em "Nova conta" para criar a primeira.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Tentar de novo')),
          ],
        ),
      ),
    );
  }
}