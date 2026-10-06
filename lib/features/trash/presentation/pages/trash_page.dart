import 'package:finly/core/di/injection.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/transactions/presentation/transaction_messages.dart';
import 'package:finly/features/transactions/presentation/transaction_style.dart';
import 'package:finly/features/trash/domain/entities/trashed_transaction.dart';
import 'package:finly/features/trash/domain/trash_rules.dart';
import 'package:finly/features/trash/presentation/cubit/trash_cubit.dart';
import 'package:finly/features/trash/presentation/cubit/trash_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The deleted transactions of one workspace, with a button to restore each.
/// The cubit is created for [workspace], so it never shows data of another
/// workspace.
class TrashPage extends StatelessWidget {
  final WorkspaceEntity workspace;
  final List<AccountEntity> accounts;
  final List<CategoryEntity> categories;

  const TrashPage({
    super.key,
    required this.workspace,
    required this.accounts,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TrashCubit>()..load(workspace.id),
      child: _TrashView(
        workspace: workspace,
        accounts: accounts,
        categories: categories,
      ),
    );
  }
}

class _TrashView extends StatelessWidget {
  final WorkspaceEntity workspace;
  final List<AccountEntity> accounts;
  final List<CategoryEntity> categories;

  const _TrashView({
    required this.workspace,
    required this.accounts,
    required this.categories,
  });

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isBusiness = workspace.type == WorkspaceType.business;

    return BlocConsumer<TrashCubit, TrashState>(
      listenWhen: (previous, current) =>
          (current.actionFailure != null &&
              previous.actionFailure != current.actionFailure) ||
          (current.restored != null && previous.restored != current.restored),
      listener: (context, state) {
        final failure = state.actionFailure;
        if (failure != null) {
          _showMessage(context, transactionFailureMessage(failure));
        } else if (state.restored != null) {
          _showMessage(context, 'Transação restaurada.');
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Lixeira'),
            backgroundColor: isBusiness ? AppColors.deepBlue : null,
            foregroundColor: isBusiness ? AppColors.white : null,
          ),
          body: _body(context, state),
        );
      },
    );
  }

  Widget _body(BuildContext context, TrashState state) {
    if (state.status == TrashStatus.failure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                transactionFailureMessage(state.failure!),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.read<TrashCubit>().reload(),
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      );
    }
    if (state.status != TrashStatus.loaded && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final text = Theme.of(context).textTheme;
    final accountById = {for (final a in accounts) a.id: a};
    final categoryById = {for (final c in categories) c.id: c};
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Transações excluídas ficam aqui por $trashRetentionDays dias '
                    'e depois são removidas de vez. Transferências excluídas '
                    'não voltam.',
                    style: text.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (state.items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Icon(Icons.delete_outline, size: 56),
                const SizedBox(height: 16),
                Text('A lixeira está vazia', style: text.titleMedium),
              ],
            ),
          )
        else
          for (final item in state.items)
            _TrashTile(
              item: item,
              categoryName:
                  categoryById[item.transaction.categoryId]?.name ?? 'Sem categoria',
              accountName: accountById[item.transaction.accountId]?.name ?? 'Conta',
              daysLeft: trashDaysLeft(item.deletedAt, now),
              onRestore: () => context.read<TrashCubit>().restore(item),
            ),
      ],
    );
  }
}

class _TrashTile extends StatelessWidget {
  final TrashedTransaction item;
  final String categoryName;
  final String accountName;
  final int daysLeft;
  final VoidCallback onRestore;

  const _TrashTile({
    required this.item,
    required this.categoryName,
    required this.accountName,
    required this.daysLeft,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final transaction = item.transaction;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    transaction.description,
                    style: text.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(transactionAmountText(transaction), style: text.titleMedium),
              ],
            ),
            Text(
              '$categoryName · $accountName · ${formatDateBr(transaction.occurredAt)}',
              style: text.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Excluída em ${formatDateBr(item.deletedAt)} · ${trashDaysLeftLabel(daysLeft)}',
              style: text.bodySmall,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.restore),
                label: const Text('Restaurar'),
                onPressed: onRestore,
              ),
            ),
          ],
        ),
      ),
    );
  }
}