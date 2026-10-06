import 'dart:async';

import 'package:finly/core/di/injection.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_filter.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/presentation/cubit/transactions_cubit.dart';
import 'package:finly/features/transactions/presentation/cubit/transactions_state.dart';
import 'package:finly/features/transactions/presentation/pages/transaction_edit_page.dart';
import 'package:finly/features/transactions/presentation/pages/transaction_form_page.dart';
import 'package:finly/features/transactions/presentation/transaction_messages.dart';
import 'package:finly/features/transactions/presentation/transaction_style.dart';
import 'package:finly/features/transactions/presentation/widgets/transaction_filter_sheet.dart';
import 'package:finly/features/transfers/presentation/pages/transfer_form_page.dart';
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

class _TransactionsView extends StatefulWidget {
  final WorkspaceEntity workspace;

  const _TransactionsView({required this.workspace});

  @override
  State<_TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends State<_TransactionsView> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  WorkspaceEntity get _workspace => widget.workspace;

  @override
  void initState() {
    super.initState();
    // Load the next page when the user gets near the end of the list.
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      if (_scroll.position.extentAfter < 400 && mounted) {
        context.read<TransactionsCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Searches a moment after the user stops typing, not on every key.
  void _onSearchChanged(String text) {
    setState(() {});
    _debounce?.cancel();
    final cubit = context.read<TransactionsCubit>();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      cubit.setFilter(cubit.state.filter.withSearch(text));
    });
  }

  void _clearSearch() {
    _search.clear();
    _debounce?.cancel();
    setState(() {});
    final cubit = context.read<TransactionsCubit>();
    cubit.setFilter(cubit.state.filter.withSearch(''));
  }

  void _clearAllFilters() {
    _search.clear();
    _debounce?.cancel();
    setState(() {});
    context.read<TransactionsCubit>().setFilter(const TransactionFilter());
  }

  Future<void> _openFilters(TransactionsState state) async {
    final cubit = context.read<TransactionsCubit>();
    final result = await showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TransactionFilterSheet(
        initial: state.filter,
        accounts: state.accounts,
        categories: state.categories,
      ),
    );
    if (result != null) await cubit.setFilter(result);
  }

  Future<void> _openForm(TransactionsState state) async {
    if (state.accounts.isEmpty) {
      _showMessage('Crie uma conta antes de lançar transações.');
      return;
    }
    final cubit = context.read<TransactionsCubit>();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TransactionFormPage(
          workspaceId: _workspace.id,
          accounts: state.accounts,
          categories: state.categories,
        ),
      ),
    );
    if (created == true) await cubit.reload();
  }

  Future<void> _openEdit(
    TransactionsState state,
    TransactionEntity transaction,
  ) async {
    if (transaction.isTransferLeg) {
      _showMessage('Transferências não podem ser editadas. Exclua e crie outra.');
      return;
    }
    if (transaction.status == TransactionStatus.failed) {
      _showMessage('Transações que falharam não podem ser editadas.');
      return;
    }

    AccountEntity? account;
    for (final candidate in state.accounts) {
      if (candidate.id == transaction.accountId) account = candidate;
    }

    final cubit = context.read<TransactionsCubit>();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TransactionEditPage(
          transaction: transaction,
          account: account,
          categories: state.categories,
        ),
      ),
    );
    if (saved == true) await cubit.reload();
  }

  Future<void> _openTransferForm(TransactionsState state) async {
    if (state.accounts.isEmpty) {
      _showMessage('Crie uma conta antes de transferir.');
      return;
    }

    // The user's other workspace, when there is one.
    WorkspaceEntity? other;
    final user = context.read<AuthBloc>().state.user;
    for (final candidate in user?.workspaces ?? const <WorkspaceEntity>[]) {
      if (candidate.id != _workspace.id) other = candidate;
    }

    final cubit = context.read<TransactionsCubit>();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TransferFormPage(
          workspace: _workspace,
          accounts: state.accounts,
          otherWorkspace: other,
        ),
      ),
    );
    if (created == true) await cubit.reload();
  }

  Future<bool> _confirmTransferDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir transferência?'),
        content: const Text(
          'As duas pontas da transferência serão excluídas e os saldos '
          'voltam ao que eram. Não é possível desfazer por aqui.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isBusiness = _workspace.type == WorkspaceType.business;

    return BlocConsumer<TransactionsCubit, TransactionsState>(
      listenWhen: (previous, current) =>
          (current.actionFailure != null &&
              previous.actionFailure != current.actionFailure) ||
          (current.deletedTransaction != null &&
              previous.deletedTransaction != current.deletedTransaction),
      listener: (context, state) {
        final failure = state.actionFailure;
        if (failure != null) {
          _showMessage(transactionFailureMessage(failure));
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
        final pickers = state.filter.pickerCount;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Transações'),
            backgroundColor: isBusiness ? AppColors.deepBlue : null,
            foregroundColor: isBusiness ? AppColors.white : null,
            actions: [
              IconButton(
                tooltip: 'Filtros',
                icon: Badge(
                  isLabelVisible: pickers > 0,
                  label: Text('$pickers'),
                  child: const Icon(Icons.filter_list),
                ),
                onPressed: () => _openFilters(state),
              ),
              IconButton(
                tooltip: 'Transferir',
                icon: const Icon(Icons.swap_horiz),
                onPressed: () => _openTransferForm(state),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openForm(state),
            icon: const Icon(Icons.add),
            label: const Text('Nova transação'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _search,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar por descrição',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar busca',
                            icon: const Icon(Icons.close),
                            onPressed: _clearSearch,
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (state.status == TransactionsStatus.loading &&
                  state.transactions.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              Expanded(child: _body(state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(TransactionsState state) {
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
    if (state.transactions.isEmpty) {
      return state.filter.isActive
          ? _NoResultsView(onClear: _clearAllFilters)
          : const _EmptyView();
    }

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
          onTap: () => _openEdit(state, transaction),
          onConfirm: () => cubit.confirm(transaction.id),
          onDelete: () => transaction.isTransferLeg
              ? cubit.deleteTransfer(transaction)
              : cubit.delete(transaction),
          confirmDelete:
              transaction.isTransferLeg ? _confirmTransferDelete : null,
        ),
      );
    }

    if (state.loadingMore) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (state.hasMore) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextButton(
            onPressed: cubit.loadMore,
            child: const Text('Carregar mais'),
          ),
        ),
      );
    }

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: children,
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionEntity transaction;
  final AccountEntity? account;
  final CategoryEntity? category;
  final VoidCallback onTap;
  final VoidCallback onConfirm;
  final VoidCallback onDelete;

  /// Asks before deleting (used for transfers). Null means no question.
  final Future<bool> Function()? confirmDelete;

  const _TransactionTile({
    required this.transaction,
    required this.account,
    required this.category,
    required this.onTap,
    required this.onConfirm,
    required this.onDelete,
    required this.confirmDelete,
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
      category?.name ??
          (transaction.isTransferLeg ? 'Transferência' : 'Sem categoria'),
      account?.name ?? 'Conta',
    ].join(' · ');

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      confirmDismiss:
          confirmDelete == null ? null : (_) => confirmDelete!.call(),
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: scheme.error,
        child: Icon(Icons.delete_outline, color: scheme.onError),
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
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
                  onSelected: (_) async {
                    final ask = confirmDelete;
                    if (ask != null && !await ask()) return;
                    onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('Excluir')),
                  ],
                ),
              ],
            ),
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

class _NoResultsView extends StatelessWidget {
  final VoidCallback onClear;

  const _NoResultsView({required this.onClear});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 56),
            const SizedBox(height: 16),
            Text('Nada encontrado', style: text.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Nenhuma transação combina com a busca e os filtros.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: onClear,
              child: const Text('Limpar filtros'),
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