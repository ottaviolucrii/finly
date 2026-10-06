import 'package:finly/core/di/injection.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/presentation/account_messages.dart';
import 'package:finly/features/accounts/presentation/account_style.dart';
import 'package:finly/features/accounts/presentation/cubit/accounts_cubit.dart';
import 'package:finly/features/accounts/presentation/cubit/accounts_state.dart';
import 'package:finly/features/accounts/presentation/cubit/archived_accounts_cubit.dart';
import 'package:finly/features/accounts/presentation/cubit/archived_accounts_state.dart';
import 'package:finly/features/accounts/presentation/pages/account_edit_page.dart';
import 'package:finly/features/accounts/presentation/pages/account_form_page.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/dashboard/domain/dashboard_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Accounts of one workspace. The cubits are created for [workspace], so they
/// never show accounts of another workspace.
class AccountsPage extends StatelessWidget {
  final WorkspaceEntity workspace;

  const AccountsPage({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<AccountsCubit>()..load(workspace.id)),
        BlocProvider(
          create: (_) => sl<ArchivedAccountsCubit>()..load(workspace.id),
        ),
      ],
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

  Future<void> _openEdit(BuildContext context, AccountEntity account) async {
    final cubit = context.read<AccountsCubit>();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AccountEditPage(account: account),
      ),
    );
    if (saved == true) await cubit.reload();
  }

  Future<void> _confirmArchive(
    BuildContext context,
    AccountEntity account,
  ) async {
    final active = context.read<AccountsCubit>();
    final archived = context.read<ArchivedAccountsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Arquivar conta?'),
        content: Text(
          'A conta "${account.name}" sai da lista, mas o histórico é mantido. '
          'Você pode restaurá-la depois, em "Arquivadas".',
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
    if (confirmed == true) {
      await active.archive(account.id);
      await archived.reload();
    }
  }

  Future<void> _restore(BuildContext context, AccountEntity account) async {
    final active = context.read<AccountsCubit>();
    final archived = context.read<ArchivedAccountsCubit>();
    final restored = await archived.restore(account);
    if (restored) await active.reload();
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

          return _AccountList(
            accounts: state.accounts,
            onEdit: (account) => _openEdit(context, account),
            onArchive: (account) => _confirmArchive(context, account),
            footer: _ArchivedSection(
              onRestore: (account) => _restore(context, account),
            ),
          );
        },
      ),
    );
  }
}

class _AccountList extends StatelessWidget {
  final List<AccountEntity> accounts;
  final void Function(AccountEntity account) onEdit;
  final void Function(AccountEntity account) onArchive;
  final Widget footer;

  const _AccountList({
    required this.accounts,
    required this.onEdit,
    required this.onArchive,
    required this.footer,
  });

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
        if (accounts.isEmpty)
          const _EmptyCard()
        else ...[
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
            _AccountTile(
              account: account,
              onTap: () => onEdit(account),
              onEdit: () => onEdit(account),
              onArchive: () => onArchive(account),
            ),
        ],
        const SizedBox(height: 8),
        footer,
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  final AccountEntity account;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  const _AccountTile({
    required this.account,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final balance = account.postedBalance;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else {
                    onArchive();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'archive', child: Text('Arquivar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The archived accounts, with a button to bring each one back.
class _ArchivedSection extends StatelessWidget {
  final void Function(AccountEntity account) onRestore;

  const _ArchivedSection({required this.onRestore});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ArchivedAccountsCubit, ArchivedAccountsState>(
      listenWhen: (previous, current) =>
          current.actionFailure != null &&
          previous.actionFailure != current.actionFailure,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(accountRestoreFailureMessage(state.actionFailure!)),
            ),
          );
      },
      builder: (context, state) {
        if (state.accounts.isEmpty) return const SizedBox.shrink();

        final text = Theme.of(context).textTheme;

        return Card(
          child: ExpansionTile(
            title: Text('Arquivadas (${state.accounts.length})'),
            children: [
              for (final account in state.accounts)
                ListTile(
                  leading: Icon(accountTypeIcon(account.type)),
                  title: Text(account.name, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${accountTypeLabel(account.type)} · ${account.currency}',
                    style: text.bodySmall,
                  ),
                  trailing: TextButton(
                    onPressed: () => onRestore(account),
                    child: const Text('Restaurar'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
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