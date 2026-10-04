import 'package:finly/core/di/injection.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/presentation/card_messages.dart';
import 'package:finly/features/cards/presentation/cubit/cards_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/cards_state.dart';
import 'package:finly/features/cards/presentation/pages/card_detail_page.dart';
import 'package:finly/features/cards/presentation/pages/card_form_page.dart';
import 'package:finly/features/cards/presentation/widgets/card_usage_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Credit cards of one workspace. The cubit is created for [workspace], so it
/// never shows cards of another workspace.
class CardsPage extends StatelessWidget {
  final WorkspaceEntity workspace;

  const CardsPage({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CardsCubit>()..load(workspace.id),
      child: _CardsView(workspace: workspace),
    );
  }
}

class _CardsView extends StatelessWidget {
  final WorkspaceEntity workspace;

  const _CardsView({required this.workspace});

  Future<void> _openForm(BuildContext context) async {
    final cubit = context.read<CardsCubit>();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CardFormPage(workspaceId: workspace.id),
      ),
    );
    if (created == true) await cubit.reload();
  }

  Future<void> _openCard(BuildContext context, CreditCardEntity card) async {
    final cubit = context.read<CardsCubit>();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CardDetailPage(workspace: workspace, card: card),
      ),
    );
    // Purchases and payments change the used limit.
    await cubit.reload();
  }

  @override
  Widget build(BuildContext context) {
    final isBusiness = workspace.type == WorkspaceType.business;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cartões'),
        backgroundColor: isBusiness ? AppColors.deepBlue : null,
        foregroundColor: isBusiness ? AppColors.white : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo cartão'),
      ),
      body: BlocBuilder<CardsCubit, CardsState>(
        builder: (context, state) {
          if (state.status == CardsStatus.failure) {
            return _ErrorView(
              message: cardFailureMessage(state.failure!),
              onRetry: () => context.read<CardsCubit>().reload(),
            );
          }
          if (state.status != CardsStatus.loaded && state.cards.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.cards.isEmpty) return const _EmptyView();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              for (final card in state.cards)
                _CardTile(card: card, onTap: () => _openCard(context, card)),
            ],
          );
        },
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final CreditCardEntity card;
  final VoidCallback onTap;

  const _CardTile({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.credit_card, color: scheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      card.name,
                      style: text.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Fecha dia ${card.closingDay} · vence dia ${card.dueDay}',
                style: text.bodySmall,
              ),
              const SizedBox(height: 12),
              CardUsageSummary(card: card),
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
            const Icon(Icons.credit_card_outlined, size: 56),
            const SizedBox(height: 16),
            Text('Nenhum cartão ainda', style: text.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Toque em "Novo cartão" para cadastrar o primeiro.',
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