import 'package:finly/core/di/injection.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/presentation/cubit/transactions_cubit.dart';
import 'package:finly/features/transactions/presentation/cubit/transactions_state.dart';
import 'package:finly/features/transactions/presentation/pages/transaction_form_page.dart';
import 'package:finly/features/transactions/presentation/transaction_messages.dart';
import 'package:finly/features/transactions/presentation/transaction_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Transactions of one workspace. The cubit is created for [workspace], so it
/// never shows data of another workspace.
class TransactionsPage extends StatelessWidget {
  final WorkspaceEntity workspace;

  const TransactionsPage({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TransactionsCubit>()..load(workspace.id),
      child: _TransactionsView(workspace: workspace),
    );
  }
}

class _TransactionsView extends StatelessWidget {
  final WorkspaceEntity workspace;

  const _TransactionsView({required this.workspace});

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openForm(BuildContext context, TransactionsState state) async {
    if (state.accounts.isEmpty) {
      _showMessage(context, 'Crie uma conta antes de lançar transações.');
      return;
    }
    final cubit = context.read<TransactionsCubit>();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TransactionFormPage(
          workspaceId: workspace.id,
          accounts: state.accounts,
          categories: state.categories,
        ),
      ),
    );
    if (created == true) await cubit.reload();
  }

  @override
  Widget build(BuildContext context) {
    final isBusiness = workspace.type == WorkspaceType.business;

    return BlocConsumer<TransactionsCubit, TransactionsState>(
      listenWhen: (previous, current) =>
          (current.actionFailure != null &&
              previous.actionFailure != current.actionFailure) ||
          (current.deletedTransaction != null &&
              previous.deletedTransaction != current.deletedTransaction),
      listener: (context, state) {
        final failure = state.actionFailure;
        if (failure != null) {
          _showMessage(context, transactionFailureMessage(failure));
          return;
        }
        if (state.deletedTransaction != null) {
          final cubit = context.read<TransactionsCubit>();
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: const Text('Transação excluída.'),
                duration: const Duration(seconds: 10),
                action: SnackBarAction(
                  label: 'Desfazer',
                  onPressed: cubit.undoDelete,
                ),
              ),
            );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Transações'),
            backgroundColor: isBusiness ? AppColors.deepBlue : null,
            foregroundColor: isBusiness ? AppColors.white : null,
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openForm(context, state),
            icon: const Icon(Icons.add),
            label: const Text('Nova transação'),
          ),
          body: _body(context, state),
        );
      },
    );
  }

  Widget _body(BuildContext context, TransactionsState state) {
    if (state.status == TransactionsStatus.failure) {
      return _ErrorView(
        message: transactionFailureMessage(state.failure!),
        onRetry: () => context.read<TransactionsCubit>().reload(),
      );
    }
    if (state.status != TransactionsStatus.loaded &&
        state.transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.transactions.isEmpty) return const _EmptyView();

    final accountById = {for (final a in state.accounts) a.id: a};
    final categoryById = {for (final c in state.categories) c.id: c};
    final now = DateTime.now();
    final text = Theme.of(context).textTheme;
    final cubit = context.read<TransactionsCubit>();

    final children = <Widget>[];
    String? lastLabel;
    for (final transaction in state.transactions) {
      final label = dayLabel(transaction.occurredAt, now);
      if (label != lastLabel) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Text(label, style: text.titleSmall),
          ),
        );
        lastLabel = label;
      }
      children.add(
        _TransactionTile(
          transaction: transaction,
          account: accountById[transaction.accountId],
          category: categoryById[transaction.categoryId],
          onConfirm: () => cubit.confirm(transaction.id),
          onDelete: () => cubit.delete(transaction),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: children,
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionEntity transaction;
  final AccountEntity? account;
  final CategoryEntity? category;
  final VoidCallback onConfirm;
  final VoidCallback onDelete;

  const _TransactionTile({
    required this.transaction,
    required this.account,
    required this.category,
    required this.onConfirm,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final avatarColor = category != null
        ? categoryColor(category!.colorHex)
        : AppColors.structure;
    final avatarForeground =
        ThemeData.estimateBrightnessForColor(avatarColor) == Brightness.dark
            ? AppColors.white
            : AppColors.midnight;
    final icon = category != null
        ? categoryIcon(category!.icon)
        : transactionTypeIcon(transaction.type);

    final subtitle = [
      category?.name ?? 'Sem categoria',
      account?.name ?? 'Conta',
    ].join(' · ');

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: scheme.error,
        child: Icon(Icons.delete_outline, color: scheme.onError),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: avatarColor,
                foregroundColor: avatarForeground,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description,
                      style: text.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: text.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    transactionAmountText(transaction),
                    style: text.titleMedium?.copyWith(
                      color: transaction.type.isCredit ? scheme.primary : null,
                    ),
                  ),
                  if (transaction.isPending) ...[
                    Text('Pendente', style: text.bodySmall),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: onConfirm,
                      child: const Text('Confirmar'),
                    ),
                  ],
                ],
              ),
              PopupMenuButton<String>(
                tooltip: 'Mais opções',
                onSelected: (_) => onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              ),
            ],
          ),
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
            const Icon(Icons.receipt_long_outlined, size: 56),
            const SizedBox(height: 16),
            Text('Nenhuma transação ainda', style: text.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Toque em "Nova transação" para lançar a primeira.',
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