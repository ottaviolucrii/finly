import 'package:finly/core/di/injection.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/recurring/domain/entities/recurring_entity.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_cubit.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_state.dart';
import 'package:finly/features/recurring/presentation/pages/recurring_form_page.dart';
import 'package:finly/features/recurring/presentation/recurring_messages.dart';
import 'package:finly/features/recurring/presentation/recurring_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Recurring bills and income of one workspace. The cubit is created for
/// [workspace], so it never shows items of another workspace.
class RecurringPage extends StatelessWidget {
  final WorkspaceEntity workspace;

  const RecurringPage({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<RecurringCubit>()..load(workspace.id),
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

  Future<void> _openForm(BuildContext context, RecurringState state) async {
    if (state.accounts.isEmpty) {
      _showMessage(context, 'Crie uma conta antes de criar uma recorrência.');
      return;
    }
    final cubit = context.read<RecurringCubit>();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => RecurringFormPage(
          workspaceId: workspace.id,
          accounts: state.accounts,
          categories: state.categories,
        ),
      ),
    );
    // Reloading also creates the pending transactions of the new item.
    if (created == true) await cubit.reload();
  }

  @override
  Widget build(BuildContext context) {
    final isBusiness = workspace.type == WorkspaceType.business;

    return BlocConsumer<RecurringCubit, RecurringState>(
      listenWhen: (previous, current) =>
          current.actionFailure != null &&
          previous.actionFailure != current.actionFailure,
      listener: (context, state) {
        _showMessage(context, recurringFailureMessage(state.actionFailure!));
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Recorrências'),
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
    if (state.items.isEmpty) return const _EmptyView();

    final accountById = {for (final a in state.accounts) a.id: a};
    final cubit = context.read<RecurringCubit>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        for (final item in state.items)
          _RecurringTile(
            item: item,
            account: accountById[item.accountId],
            onToggle: () => cubit.toggleActive(item),
          ),
      ],
    );
  }
}

class _RecurringTile extends StatelessWidget {
  final RecurringEntity item;
  final AccountEntity? account;
  final VoidCallback onToggle;

  const _RecurringTile({
    required this.item,
    required this.account,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final next = item.nextDate(DateTime.now());
    final status = !item.isActive
        ? 'Pausada'
        : (next == null ? 'Encerrada' : 'Próxima: ${formatDateBr(next)}');
    final sign = item.type.isCredit ? '+' : '-';

    // The description gets a full line (two at most) and the amount its own
    // line, so nothing is cut off on a narrow phone or with a large font.
    return Opacity(
      opacity: item.isActive ? 1 : 0.6,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.repeat, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.description,
                      style: text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Mais opções',
                    onSelected: (_) => onToggle(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(item.isActive ? 'Pausar' : 'Retomar'),
                      ),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 36, right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$sign ${item.amount.format()}',
                      style: text.titleLarge?.copyWith(
                        color: item.type.isCredit ? scheme.primary : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${frequencyLabel(item.frequency, item.intervalCount)} · '
                      '${account?.name ?? 'Conta'}',
                      style: text.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(status, style: text.bodySmall),
                  ],
                ),
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