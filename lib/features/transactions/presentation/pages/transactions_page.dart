import 'dart:async';

import 'package:finly/core/di/injection.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/dashboard/presentation/cubit/month_totals_cubit.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_filter.dart';
import 'package:finly/features/trash/presentation/pages/trash_page.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/presentation/cubit/transactions_cubit.dart';
import 'package:finly/features/transactions/presentation/cubit/transactions_state.dart';
import 'package:finly/features/transactions/presentation/pages/transaction_edit_page.dart';
import 'package:finly/features/transactions/presentation/statement_filters.dart';
import 'package:finly/features/transactions/presentation/transaction_messages.dart';
import 'package:finly/features/transactions/presentation/widgets/statement_band.dart';
import 'package:finly/features/transactions/presentation/widgets/statement_list.dart';
import 'package:finly/features/transactions/presentation/widgets/new_transaction_sheet.dart';
import 'package:finly/features/transactions/presentation/widgets/transaction_filter_sheet.dart';
import 'package:finly/features/transfers/presentation/pages/transfer_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Extrato: the transactions of one workspace, a month at a time. The cubits
/// are created for [workspace], so it never shows data of another workspace.
class TransactionsPage extends StatelessWidget {
  final WorkspaceEntity workspace;

  /// "Now", to start on the current month; tests pass a fixed date.
  final DateTime Function()? clock;

  /// Starts with only this account (a tap on an account card on Início).
  final String? accountId;

  const TransactionsPage({super.key, required this.workspace, this.clock, this.accountId});

  @override
  Widget build(BuildContext context) {
    final now = (clock ?? DateTime.now)();
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<TransactionsCubit>()
            ..load(workspace.id, filter: filterForMonth(TransactionFilter(accountId: accountId), now)),
        ),
        BlocProvider(create: (_) => sl<MonthTotalsCubit>()..load(workspace.id, now)),
      ],
      child: _TransactionsView(workspace: workspace, now: now),
    );
  }
}

class _TransactionsView extends StatefulWidget {
  final WorkspaceEntity workspace;
  final DateTime now;

  const _TransactionsView({required this.workspace, required this.now});

  @override
  State<_TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends State<_TransactionsView> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  /// The search box is open.
  bool _searching = false;

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

  void _toggleSearch() {
    if (_searching) {
      setState(() => _searching = false);
      if (_search.text.isNotEmpty) _clearSearch();
    } else {
      setState(() => _searching = true);
    }
  }

  void _clearAllFilters() {
    _search.clear();
    _debounce?.cancel();
    setState(() => _searching = false);
    final cubit = context.read<TransactionsCubit>();
    // Back to the month that was shown (or this month), nothing else set.
    final month = monthOfFilter(cubit.state.filter) ?? widget.now;
    cubit.setFilter(filterForMonth(const TransactionFilter(), month));
  }

  /// Moves the statement [months] months from the one shown.
  void _moveMonth(int months) {
    final cubit = context.read<TransactionsCubit>();
    final filter = cubit.state.filter;
    final shown = monthOfFilter(filter) ?? widget.now;
    cubit.setFilter(filterForMonth(filter, DateTime(shown.year, shown.month + months)));
  }

  void _thisMonth() {
    final cubit = context.read<TransactionsCubit>();
    cubit.setFilter(filterForMonth(cubit.state.filter, widget.now));
  }

  void _confirm(String id) {
    final totals = context.read<MonthTotalsCubit>();
    context.read<TransactionsCubit>().confirm(id).then((_) => totals.reload());
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

  Future<void> _openTrash() async {
    final cubit = context.read<TransactionsCubit>();
    final state = cubit.state;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TrashPage(
          workspace: _workspace,
          accounts: state.accounts,
          categories: state.categories,
        ),
      ),
    );
    // Something may have been restored.
    await cubit.reload();
  }

  Future<void> _openForm(TransactionsState state) async {
    if (state.accounts.isEmpty) {
      _showMessage('Crie uma conta antes de lançar transações.');
      return;
    }
    final cubit = context.read<TransactionsCubit>();
    final result = await showNewTransactionSheet(
      context,
      workspaceId: _workspace.id,
      accounts: state.accounts,
      categories: state.categories,
    );
    if (result == NewTransactionResult.created) {
      await cubit.reload();
    } else if (result == NewTransactionResult.transfer && mounted) {
      await _openTransferForm(cubit.state);
    }
  }

  Future<void> _openEdit(
    TransactionsState state,
    TransactionEntity transaction,
  ) async {
    if (transaction.isTransferLeg) {
      _showMessage(
        'Transferências não podem ser editadas. Exclua e crie outra.',
      );
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
          'voltam ao que eram. Você pode restaurá-la na Lixeira por 30 dias.',
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
    return MultiBlocListener(
      listeners: [
        BlocListener<TransactionsCubit, TransactionsState>(
          // The month (or anything) read again: so do the totals of the band.
          listenWhen: (previous, current) =>
              current.status == TransactionsStatus.loading &&
              previous.status != TransactionsStatus.loading,
          listener: (context, state) {
            final month = monthOfFilter(state.filter);
            if (month != null) context.read<MonthTotalsCubit>().load(_workspace.id, month);
          },
        ),
        BlocListener<TransactionsCubit, TransactionsState>(
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
              final totals = context.read<MonthTotalsCubit>();
              totals.reload();
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: const Text('Transação excluída.'),
                    duration: const Duration(seconds: 10),
                    action: SnackBarAction(
                      label: 'Desfazer',
                      onPressed: () => cubit.undoDelete().then((_) => totals.reload()),
                    ),
                  ),
                );
            }
          },
        ),
      ],
      child: BlocBuilder<TransactionsCubit, TransactionsState>(
        builder: (context, state) {
          final filter = state.filter;
          final month = monthOfFilter(filter);
          final period = month != null
              ? StatementPeriod.month
              : (filter.hasPeriod ? StatementPeriod.custom : StatementPeriod.all);
          // Opened from another screen (no tab bar): its own back arrow and "+".
          final pushed = ModalRoute.of(context)?.canPop ?? false;
          final showSearch = _searching || _search.text.isNotEmpty;

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: Scaffold(
              floatingActionButton: pushed
                  ? FloatingActionButton(
                      tooltip: 'Nova transação',
                      onPressed: () => _openForm(state),
                      child: const Icon(Icons.add),
                    )
                  : null,
              body: Column(
                children: [
                  BlocBuilder<MonthTotalsCubit, MonthTotalsState>(
                    builder: (context, totals) => StatementBand(
                      month: month ?? widget.now,
                      period: period,
                      totals: totals.main,
                      loadingTotals: totals.status == MonthTotalsStatus.loading && totals.entries.isEmpty,
                      filterCount: sheetFilterCount(filter),
                      searching: showSearch,
                      showBack: pushed,
                      onPrevious: () => _moveMonth(-1),
                      onNext: () => _moveMonth(1),
                      onThisMonth: _thisMonth,
                      onSearch: _toggleSearch,
                      onFilters: () => _openFilters(state),
                      onTransfer: () => _openTransferForm(state),
                      onTrash: _openTrash,
                    ),
                  ),
                  if (showSearch)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: TextField(
                        controller: _search,
                        autofocus: _search.text.isEmpty,
                        onChanged: _onSearchChanged,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Buscar por descrição',
                          isDense: true,
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpar busca',
                                  icon: const Icon(Icons.close),
                                  onPressed: _clearSearch,
                                ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  QuickFilterChips(
                    selected: quickOf(filter),
                    onSelected: (quick) =>
                        context.read<TransactionsCubit>().setFilter(filterWithQuick(filter, quick)),
                  ),
                  if (state.status == TransactionsStatus.loading && state.transactions.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    )
                  else
                    const SizedBox(height: 10),
                  Expanded(child: _body(state)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _body(TransactionsState state) {
    if (state.status == TransactionsStatus.failure) {
      return _ErrorView(
        message: transactionFailureMessage(state.failure!),
        onRetry: () => context.read<TransactionsCubit>().reload(),
      );
    }
    if (state.status != TransactionsStatus.loaded && state.transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.transactions.isEmpty) {
      final onlyMonth = state.filter.search.trim().isEmpty &&
          state.filter.type == null &&
          state.filter.status == null &&
          state.filter.accountId == null &&
          state.filter.categoryId == null;
      if (onlyMonth && monthOfFilter(state.filter) != null) return const _EmptyMonthView();
      return state.filter.isActive ? _NoResultsView(onClear: _clearAllFilters) : const _EmptyView();
    }

    final accountById = {for (final a in state.accounts) a.id: a};
    final categoryById = {for (final c in state.categories) c.id: c};
    final now = DateTime.now();
    final cubit = context.read<TransactionsCubit>();

    // Consecutive transactions of the same day go in one card.
    final groups = <({String label, List<TransactionEntity> items})>[];
    for (final transaction in state.transactions) {
      final label = dayLabel(transaction.occurredAt, now);
      if (groups.isEmpty || groups.last.label != label) {
        groups.add((label: label, items: [transaction]));
      } else {
        groups.last.items.add(transaction);
      }
    }

    final children = <Widget>[];
    for (final group in groups) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 20));
      children.add(
        StatementDayGroup(
          label: group.label,
          rows: [
            for (final transaction in group.items)
              StatementRow(
                transaction: transaction,
                account: accountById[transaction.accountId],
                category: categoryById[transaction.categoryId],
                onTap: () => _openEdit(state, transaction),
                onConfirm: () => _confirm(transaction.id),
                onDelete: () => transaction.isTransferLeg
                    ? cubit.deleteTransfer(transaction)
                    : cubit.delete(transaction),
                confirmDelete: transaction.isTransferLeg ? _confirmTransferDelete : null,
              ),
          ],
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

    return RefreshIndicator(
      onRefresh: () => cubit.reload(),
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: children,
      ),
    );
  }
}

class _EmptyMonthView extends StatelessWidget {
  const _EmptyMonthView();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_note_outlined, size: 56),
            const SizedBox(height: 16),
            Text('Nada neste mês', style: text.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Use as setas para ver outro mês, ou toque no + para lançar.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
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
            const Icon(Icons.receipt_long_outlined, size: 56),
            const SizedBox(height: 16),
            Text('Nenhuma transação ainda', style: text.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Toque no + para lançar a primeira.',
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
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      ),
    );
  }
}
