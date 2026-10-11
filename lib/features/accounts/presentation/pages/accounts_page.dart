import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/widgets/grouped_list.dart';
import 'package:finly/core/widgets/workspace_title.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
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
import 'package:finly/features/dashboard/domain/entities/dashboard_data.dart';
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
        title: WorkspaceTitle('Contas', isBusiness: isBusiness),
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
    // Credit cards are not part of the total (it is what you have); what is
    // owed on them is shown on its own line, like on the dashboard.
    final totals = totalsByCurrency(accounts);
    final regular = [for (final a in accounts) if (a.type != AccountType.creditCard) a];
    final cards = [for (final a in accounts) if (a.type == AccountType.creditCard) a];

    Widget group(List<AccountEntity> list) => Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const Divider(indent: 68),
                _AccountRow(
                  account: list[i],
                  onTap: () => onEdit(list[i]),
                  onEdit: () => onEdit(list[i]),
                  onArchive: () => onArchive(list[i]),
                ),
              ],
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      children: [
        if (accounts.isEmpty)
          const _EmptyCard()
        else ...[
          _TotalCard(totals: totals, count: regular.length),
          if (regular.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionLabel('Contas'),
            group(regular),
          ],
          if (cards.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionLabel('Cartões de crédito'),
            group(cards),
          ],
        ],
        const SizedBox(height: 20),
        footer,
      ],
    );
  }
}

/// The dark blue card at the top: the balance in accounts and, below it, what
/// is expected, what is in use on cards and how many accounts there are.
class _TotalCard extends StatelessWidget {
  final List<CurrencyBalance> totals;
  final int count;

  const _TotalCard({required this.totals, required this.count});

  @override
  Widget build(BuildContext context) {
    final main = totals.isEmpty ? null : totals.first;

    Widget pill(String label, String? value, {Color valueColor = AppColors.white}) => Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: AppColors.onBand)),
              if (value != null) ...[
                const SizedBox(width: 6),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor)),
              ],
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.deepBlue, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Saldo em contas', style: TextStyle(fontSize: 13, color: AppColors.onBand)),
          const SizedBox(height: 4),
          Text(
            main == null ? 'R\$ 0,00' : main.posted.format(),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 30,
              color: main != null && main.postedCents < 0 ? AppColors.goldOnBand : AppColors.white,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          for (final other in totals.skip(1))
            Text(
              other.posted.format(),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.white),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (main != null && main.hasPendingEffect) pill('Previsto', main.projected.format()),
              if (main != null && main.cardDebtCents > 0)
                pill('Cartões em uso', main.cardDebt.format(), valueColor: AppColors.goldOnBand),
              pill(count == 1 ? '1 conta' : '$count contas', null),
            ],
          ),
        ],
      ),
    );
  }
}

/// One account in the list: its icon, name, type and balance (in red below
/// zero), what is expected when something is pending, and its menu.
class _AccountRow extends StatelessWidget {
  final AccountEntity account;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  const _AccountRow({
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
    final card = account.type == AccountType.creditCard;
    final used = Money(-balance.cents, balance.currency);

    final String amount;
    if (card) {
      amount = balance.cents < 0 ? 'Em uso ${used.format()}' : 'Sem uso';
    } else {
      amount = balance.format();
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
        child: Row(
          children: [
            IconBadge(icon: accountTypeIcon(account.type)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    accountTypeLabel(account.type),
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: text.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: !card && balance.isNegative ? scheme.error : null,
                  ),
                ),
                if (!card && account.hasPendingEffect)
                  Text(
                    'Previsto ${account.projectedBalance.format()}',
                    style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
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
    );
  }
}

/// The archived accounts, folded in one row, with a button to bring each one
/// back.
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
        final count = state.accounts.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('Arquivadas'),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                leading: const IconBadge(icon: Icons.inventory_2_outlined),
                title: Text(count == 1 ? '1 conta arquivada' : '$count contas arquivadas'),
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
            ),
          ],
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