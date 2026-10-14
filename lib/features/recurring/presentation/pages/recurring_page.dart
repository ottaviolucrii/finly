import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/core/widgets/grouped_list.dart';
import 'package:finly/core/widgets/workspace_title.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/recurring/data/recurring_suggestion_source.dart';
import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:finly/features/recurring/domain/entities/recurring_entity.dart';
import 'package:finly/features/recurring/domain/entities/recurring_suggestion.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_cubit.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_delete_cubit.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_delete_state.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_state.dart';
import 'package:finly/features/recurring/presentation/pages/recurring_edit_page.dart';
import 'package:finly/features/recurring/presentation/pages/recurring_form_page.dart';
import 'package:finly/features/recurring/presentation/recurring_messages.dart';
import 'package:finly/features/recurring/presentation/recurring_style.dart';
import 'package:finly/features/recurring/presentation/widgets/recurring_suggestions_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Recurring bills and income of one workspace. The cubits are created for
/// [workspace], so they never show items of another workspace.
class RecurringPage extends StatelessWidget {
  final WorkspaceEntity workspace;

  const RecurringPage({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<RecurringCubit>()..load(workspace.id)),
        BlocProvider(create: (_) => sl<RecurringDeleteCubit>()),
      ],
      child: _RecurringView(workspace: workspace),
    );
  }
}

class _RecurringView extends StatelessWidget {
  final WorkspaceEntity workspace;

  const _RecurringView({required this.workspace});

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Opens the form (filled in when it comes from a suggestion); true when
  /// the recurring item was created.
  Future<bool> _openForm(BuildContext context, RecurringState state, {RecurringSuggestion? suggestion}) async {
    if (state.accounts.isEmpty) {
      _showMessage(context, 'Crie uma conta antes de criar uma recorrência.');
      return false;
    }
    final cubit = context.read<RecurringCubit>();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RecurringFormPage(
          workspaceId: workspace.id,
          accounts: state.accounts,
          categories: state.categories,
          suggestion: suggestion,
        ),
      ),
    );
    // Reloading also creates the pending transactions of the new item.
    if (created == true) await cubit.reload();
    return created == true;
  }

  /// "A Amora notou": what repeats every month and is not recurring yet; null
  /// when the app has no source for it.
  Widget? _suggestions(BuildContext context, RecurringState state) {
    if (!sl.isRegistered<RecurringSuggestionSource>()) return null;
    final accountById = {for (final a in state.accounts) a.id: a};
    return RecurringSuggestionsSection(
      workspaceId: workspace.id,
      source: sl<RecurringSuggestionSource>(),
      currencyOf: (suggestion) => accountById[suggestion.accountId]?.currency ?? 'BRL',
      onCreate: (suggestion) => _openForm(context, state, suggestion: suggestion),
    );
  }

  Future<void> _openEdit(
    BuildContext context,
    RecurringState state,
    RecurringEntity item,
  ) async {
    AccountEntity? account;
    for (final candidate in state.accounts) {
      if (candidate.id == item.accountId) account = candidate;
    }

    final cubit = context.read<RecurringCubit>();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RecurringEditPage(
          item: item,
          account: account,
          categories: state.categories,
        ),
      ),
    );
    if (saved == true) await cubit.reload();
  }

  Future<void> _confirmDelete(BuildContext context, RecurringEntity item) async {
    final deleteCubit = context.read<RecurringDeleteCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir recorrência?'),
        content: Text(
          '"${item.description}" deixa de gerar lançamentos. Os lançamentos '
          'pendentes dela são excluídos; o que já foi confirmado continua no '
          'histórico. Para só parar por um tempo, use "Pausar".',
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
    if (confirmed == true) await deleteCubit.delete(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final isBusiness = workspace.type == WorkspaceType.business;

    return BlocListener<RecurringDeleteCubit, RecurringDeleteState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == RecurringDeleteStatus.deleted) {
          _showMessage(context, 'Recorrência excluída.');
          context.read<RecurringCubit>().reload();
        } else if (state.status == RecurringDeleteStatus.failure &&
            state.failure != null) {
          _showMessage(context, recurringFailureMessage(state.failure!));
        }
      },
      child: BlocConsumer<RecurringCubit, RecurringState>(
        listenWhen: (previous, current) =>
            current.actionFailure != null &&
            previous.actionFailure != current.actionFailure,
        listener: (context, state) {
          _showMessage(context, recurringFailureMessage(state.actionFailure!));
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: WorkspaceTitle('Recorrências', isBusiness: isBusiness),
              backgroundColor: isBusiness ? AppColors.deepBlue : null,
              foregroundColor: isBusiness ? AppColors.white : null,
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _openForm(context, state),
              icon: const Icon(Icons.add),
              label: const Text('Nova recorrência'),
            ),
            body: _body(context, state),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, RecurringState state) {
    if (state.status == RecurringStatus.failure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                recurringFailureMessage(state.failure!),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.read<RecurringCubit>().reload(),
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      );
    }
    if (state.status != RecurringStatus.loaded && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final suggestions = _suggestions(context, state);
    if (state.items.isEmpty) {
      return suggestions == null
          ? const _EmptyView()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
              children: [suggestions, const _EmptyView()],
            );
    }

    final accountById = {for (final a in state.accounts) a.id: a};
    final cubit = context.read<RecurringCubit>();
    final incomes = [for (final item in state.items) if (item.type.isCredit) item];
    final expenses = [for (final item in state.items) if (!item.type.isCredit) item];

    Widget group(List<RecurringEntity> list) => Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const Divider(indent: 68),
                _RecurringTile(
                  item: list[i],
                  account: accountById[list[i].accountId],
                  onTap: () => _openEdit(context, state, list[i]),
                  onEdit: () => _openEdit(context, state, list[i]),
                  onToggle: () => cubit.toggleActive(list[i]),
                  onDelete: () => _confirmDelete(context, list[i]),
                ),
              ],
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      children: [
        ?suggestions,
        _MonthlySummary(items: state.items, today: DateTime.now()),
        if (incomes.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionLabel('Entradas'),
          group(incomes),
        ],
        if (expenses.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionLabel('Saídas'),
          group(expenses),
        ],
      ],
    );
  }
}

/// What an item adds up to in a month, on average: weekly ones count 52/12
/// times, yearly ones a twelfth, every 2 months half, and so on.
int monthlyEquivalentCents(RecurringEntity item) {
  final every = item.intervalCount < 1 ? 1 : item.intervalCount;
  final perMonth = switch (item.frequency) {
    RecurrenceFrequency.daily => item.amountCents * 365 / 12,
    RecurrenceFrequency.weekly => item.amountCents * 52 / 12,
    RecurrenceFrequency.monthly => item.amountCents.toDouble(),
    RecurrenceFrequency.yearly => item.amountCents / 12,
  };
  return (perMonth / every).round();
}

/// True while the item still makes transactions (not paused, not ended).
bool isRunning(RecurringEntity item, DateTime today) =>
    item.isActive && item.nextDate(today) != null;

/// The top card: how much comes in and goes out each month from what repeats
/// (paused and ended items left out), and what is left of it.
class _MonthlySummary extends StatelessWidget {
  final List<RecurringEntity> items;
  final DateTime today;

  const _MonthlySummary({required this.items, required this.today});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Items in other currencies are not added to the first one.
    final currency = items.first.currency;
    var incoming = 0, outgoing = 0;
    for (final item in items) {
      if (item.currency != currency || !isRunning(item, today)) continue;
      if (item.type.isCredit) {
        incoming += monthlyEquivalentCents(item);
      } else {
        outgoing += monthlyEquivalentCents(item);
      }
    }
    final left = incoming - outgoing;
    String money(int cents) => Money(cents, currency).format();

    Widget tile(String label, String value, Color background, Color foreground) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: foreground)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: foreground)),
                ),
              ],
            ),
          ),
        );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Todo mês, pelo que se repete', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Row(
              children: [
                tile(
                  'Entra',
                  money(incoming),
                  dark ? AppColors.positive.withValues(alpha: 0.25) : AppColors.positiveTint,
                  dark ? const Color(0xFF6FD39B) : AppColors.positive,
                ),
                const SizedBox(width: 12),
                tile(
                  'Sai',
                  money(outgoing),
                  dark ? AppColors.gold.withValues(alpha: 0.18) : AppColors.goldTint,
                  dark ? AppColors.goldOnBand : AppColors.goldOnLight,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              left >= 0
                  ? 'Sobram uns ${money(left)} por mês antes dos outros gastos.'
                  : 'Sai mais do que entra: faltam uns ${money(-left)} por mês.',
              style: text.bodySmall?.copyWith(
                color: left < 0 ? scheme.error : scheme.onSurfaceVariant,
                fontWeight: left < 0 ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringTile extends StatelessWidget {
  final RecurringEntity item;
  final AccountEntity? account;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _RecurringTile({
    required this.item,
    required this.account,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final next = item.nextDate(DateTime.now());
    final credit = item.type.isCredit;
    final amountColor = credit ? (dark ? const Color(0xFF6FD39B) : AppColors.positive) : null;

    final Widget status;
    if (!item.isActive || next == null) {
      status = Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: dark ? AppColors.borderDark : AppColors.hairline,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Text(
          item.isActive ? 'Encerrada' : 'Pausada',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
        ),
      );
    } else {
      status = Text(
        'Próxima ${formatDateBr(next).substring(0, 5)}',
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      );
    }

    return Opacity(
      opacity: item.isActive ? 1 : 0.6,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
          child: Row(
            children: [
              IconBadge(icon: credit ? Icons.south_west : Icons.repeat),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.description,
                      style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${frequencyLabel(item.frequency, item.intervalCount)} · ${account?.name ?? 'Conta'}',
                      style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 2,
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
                    '${credit ? '+ ' : ''}${item.amount.format()}',
                    style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700, color: amountColor),
                  ),
                  const SizedBox(height: 4),
                  status,
                ],
              ),
              PopupMenuButton<String>(
                tooltip: 'Mais opções',
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'toggle':
                      onToggle();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(item.isActive ? 'Pausar' : 'Retomar'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Excluir')),
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
            const Icon(Icons.repeat, size: 56),
            const SizedBox(height: 16),
            Text('Nenhuma recorrência ainda', style: text.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Cadastre aluguel, assinaturas ou salário. Os lançamentos '
              'aparecem como pendentes em Transações, prontos para confirmar.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}