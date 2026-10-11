import 'package:finly/core/di/injection.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/domain/usecases/get_invoices_use_case.dart';
import 'package:finly/features/cards/presentation/card_messages.dart';
import 'package:finly/features/cards/presentation/card_style.dart';
import 'package:finly/features/cards/presentation/cubit/card_archive_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/card_archive_state.dart';
import 'package:finly/features/cards/presentation/cubit/cards_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/cards_state.dart';
import 'package:finly/features/cards/presentation/pages/card_edit_page.dart';
import 'package:finly/features/cards/presentation/pages/card_form_page.dart';
import 'package:finly/features/cards/presentation/widgets/card_carousel.dart';
import 'package:finly/features/cards/presentation/widgets/card_details_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The credit cards of one workspace in a carousel, with everything about the
/// card in front below it. The cubits are created for [workspace], so it never
/// shows cards of another workspace.
class CardsPage extends StatelessWidget {
  final WorkspaceEntity workspace;

  /// Starts on the card with a closed invoice still to pay ("Pagar fatura"
  /// on Início); otherwise on the first card.
  final bool preferDue;

  /// "Today"; tests pass a fixed date.
  final DateTime Function()? clock;

  const CardsPage({super.key, required this.workspace, this.preferDue = false, this.clock});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<CardsCubit>()..load(workspace.id)),
        BlocProvider(create: (_) => sl<CardArchiveCubit>()),
      ],
      child: _CardsView(workspace: workspace, preferDue: preferDue, clock: clock ?? DateTime.now),
    );
  }
}

class _CardsView extends StatefulWidget {
  final WorkspaceEntity workspace;
  final bool preferDue;
  final DateTime Function() clock;

  const _CardsView({required this.workspace, required this.preferDue, required this.clock});

  @override
  State<_CardsView> createState() => _CardsViewState();
}

class _CardsViewState extends State<_CardsView> {
  final _pages = PageController(viewportFraction: CardCarousel.viewportFraction);

  /// The place in front of the carousel.
  int _index = 0;

  /// Goes up after an edit, so the details of the card read again.
  int _version = 0;

  /// The first list arrived (the start card was chosen).
  bool _started = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int index, {bool animate = true}) {
    if (!_pages.hasClients) return;
    if (animate) {
      _pages.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    } else {
      _pages.jumpToPage(index);
    }
  }

  /// The first time the cards arrive: when the person came to pay, go to the
  /// card with a closed invoice still to pay.
  Future<void> _start(List<CreditCardEntity> cards) async {
    _started = true;
    if (!widget.preferDue || cards.length < 2) return;

    final getInvoices = sl<GetInvoicesUseCase>();
    final results = await Future.wait([for (final card in cards) getInvoices(card.accountId)]);
    if (!mounted) return;

    final byCard = <String, List<InvoiceEntity>>{};
    for (var i = 0; i < cards.length; i++) {
      results[i].fold((_) {}, (invoices) => byCard[cards[i].accountId] = invoices);
    }
    final target = cardIndexToPay(cards, byCard, widget.clock());
    if (target != _index) {
      setState(() => _index = target);
      WidgetsBinding.instance.addPostFrameCallback((_) => _go(target, animate: false));
    }
  }

  Future<void> _openForm() async {
    final cubit = context.read<CardsCubit>();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => CardFormPage(workspaceId: widget.workspace.id)),
    );
    if (created == true) await cubit.reload();
  }

  Future<void> _openEdit(CreditCardEntity current) async {
    final cubit = context.read<CardsCubit>();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => CardEditPage(card: current)),
    );
    if (saved == true) {
      await cubit.reload();
      if (mounted) setState(() => _version++);
    }
  }

  Future<void> _archive(CreditCardEntity current) async {
    final archiveCubit = context.read<CardArchiveCubit>();

    if (current.usedCents > 0) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Este cartão está em uso'),
          content: Text(
            'Ainda há ${current.used.format()} em aberto. Pague as faturas '
            'antes de arquivar: um cartão arquivado some das listas e você '
            'não conseguiria mais pagá-las.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Arquivar cartão?'),
        content: Text(
          '"${current.name}" sai da lista de cartões, mas o histórico é '
          'mantido. Você pode restaurá-lo em Contas, na seção "Arquivadas".',
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
    if (confirmed == true) await archiveCubit.archive(current.accountId);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<CardsCubit, CardsState>(
          listenWhen: (previous, current) => !_started && current.status == CardsStatus.loaded,
          listener: (context, state) => _start(state.cards),
        ),
        BlocListener<CardsCubit, CardsState>(
          // A card left the list (archived): keep the place in front valid.
          listenWhen: (previous, current) => current.cards.length < previous.cards.length,
          listener: (context, state) {
            final last = state.cards.isEmpty ? 0 : state.cards.length - 1;
            if (_index > last) {
              setState(() => _index = last);
              _go(last, animate: false);
            }
          },
        ),
        BlocListener<CardArchiveCubit, CardArchiveState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            final messenger = ScaffoldMessenger.of(context);
            if (state.status == CardArchiveStatus.failure && state.failure != null) {
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(cardFailureMessage(state.failure!))));
            }
            if (state.status == CardArchiveStatus.archived) {
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Cartão arquivado. Para trazê-lo de volta, use Contas, '
                      'seção "Arquivadas".',
                    ),
                  ),
                );
              context.read<CardsCubit>().reload();
            }
          },
        ),
      ],
      child: BlocBuilder<CardsCubit, CardsState>(
        builder: (context, state) {
          final cards = state.cards;
          final current = _index < cards.length ? cards[_index] : null;
          final today = widget.clock();

          return Scaffold(
            appBar: AppBar(
              title: const Text('Cartões'),
              actions: [
                if (current != null) ...[
                  TextButton(onPressed: () => _openEdit(current), child: const Text('Editar')),
                  PopupMenuButton<String>(
                    tooltip: 'Mais opções',
                    onSelected: (_) => _archive(current),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'archive', child: Text('Arquivar cartão')),
                    ],
                  ),
                ],
              ],
            ),
            body: _body(context, state, current, today),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, CardsState state, CreditCardEntity? current, DateTime today) {
    final cubit = context.read<CardsCubit>();

    if (state.status == CardsStatus.failure && state.cards.isEmpty) {
      return _ErrorView(message: cardFailureMessage(state.failure!), onRetry: cubit.reload);
    }
    if (state.status != CardsStatus.loaded && state.cards.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await cubit.reload();
        if (mounted) setState(() => _version++);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          CardCarousel(
            cards: state.cards,
            controller: _pages,
            index: _index,
            onChanged: (index) => setState(() => _index = index),
            onAdd: _openForm,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: current == null
                ? AddCardHint(first: state.cards.isEmpty, onAdd: _openForm)
                : CardDetailsSection(
                    key: ValueKey('${current.accountId}-$_version'),
                    workspace: widget.workspace,
                    card: current,
                    today: today,
                    onChanged: cubit.reload,
                  ),
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