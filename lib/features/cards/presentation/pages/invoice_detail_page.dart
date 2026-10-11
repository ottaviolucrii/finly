import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/widgets/grouped_list.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/entities/invoice_entity.dart';
import 'package:finly/features/cards/presentation/card_messages.dart';
import 'package:finly/features/cards/presentation/card_style.dart';
import 'package:finly/features/cards/presentation/cubit/invoice_detail_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/invoice_detail_state.dart';
import 'package:finly/features/cards/presentation/widgets/invoice_pay_sheet.dart';
import 'package:finly/features/cards/presentation/widgets/invoice_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// One invoice: its total, what was paid and what is still owed, when it
/// closes and is due, the purchases inside it, and the button to pay it (all
/// of it or a part).
class InvoiceDetailPage extends StatelessWidget {
  final WorkspaceEntity workspace;
  final CreditCardEntity card;
  final InvoiceEntity invoice;

  /// Opens the payment as soon as the accounts are loaded ("Pagar fatura" on
  /// the card screen).
  final bool startPaying;

  /// "Today"; tests pass a fixed date.
  final DateTime Function()? clock;

  const InvoiceDetailPage({
    super.key,
    required this.workspace,
    required this.card,
    required this.invoice,
    this.startPaying = false,
    this.clock,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<InvoiceDetailCubit>()..load(invoice, card),
      child: _InvoiceDetailView(
        card: card,
        invoice: invoice,
        startPaying: startPaying,
        clock: clock ?? DateTime.now,
      ),
    );
  }
}

class _InvoiceDetailView extends StatefulWidget {
  final CreditCardEntity card;
  final InvoiceEntity invoice;
  final bool startPaying;
  final DateTime Function() clock;

  const _InvoiceDetailView({
    required this.card,
    required this.invoice,
    required this.startPaying,
    required this.clock,
  });

  @override
  State<_InvoiceDetailView> createState() => _InvoiceDetailViewState();
}

class _InvoiceDetailViewState extends State<_InvoiceDetailView> {
  /// The payment was already opened by itself once (it never opens twice).
  bool _offeredPayment = false;

  CreditCardEntity get _card => widget.card;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openPaySheet(InvoiceEntity current, List<AccountEntity> sources) {
    // The sheet lives in its own route, so hand it the cubit explicitly.
    final cubit = context.read<InvoiceDetailCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => InvoicePaySheet(
        invoice: current,
        currency: _card.currency,
        sources: sources,
        onConfirm: (accountId, amountCents) => cubit.pay(accountId, amountCents: amountCents),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // "Pagar fatura" on the card screen: open the payment once the
        // accounts to pay from are here.
        BlocListener<InvoiceDetailCubit, InvoiceDetailState>(
          listenWhen: (previous, current) =>
              widget.startPaying &&
              !_offeredPayment &&
              current.status == InvoiceDetailStatus.loaded,
          listener: (context, state) {
            _offeredPayment = true;
            final current = state.invoice ?? widget.invoice;
            if (current.needsPayment) _openPaySheet(current, state.accounts);
          },
        ),
        BlocListener<InvoiceDetailCubit, InvoiceDetailState>(
          listenWhen: (previous, current) =>
              (current.actionFailure != null && previous.actionFailure != current.actionFailure) ||
              (previous.invoice != null &&
                  current.invoice != null &&
                  current.invoice!.paidCents > previous.invoice!.paidCents),
          listener: (context, state) {
            final failure = state.actionFailure;
            if (failure != null) {
              _showMessage(cardFailureMessage(failure));
              return;
            }

            final paid = state.invoice;
            if (paid == null) return;
            if (paid.isPaid) {
              _showMessage('Fatura paga.');
            } else {
              final left = Money(paid.remainingCents, _card.currency).format();
              _showMessage('Pagamento registrado. Falta $left.');
            }
          },
        ),
      ],
      child: BlocBuilder<InvoiceDetailCubit, InvoiceDetailState>(
        builder: (context, state) {
          final current = state.invoice ?? widget.invoice;
          final today = widget.clock();

          return Scaffold(
            appBar: AppBar(title: Text(invoiceTitle(current, today))),
            body: RefreshIndicator(
              onRefresh: () => context.read<InvoiceDetailCubit>().reload(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  InvoiceSummaryCard(
                    invoice: current,
                    currency: _card.currency,
                    today: today,
                    cardName: _card.name,
                    paying: state.paying,
                    onPay: state.status == InvoiceDetailStatus.loaded
                        ? () => _openPaySheet(current, state.accounts)
                        : null,
                  ),
                  const SizedBox(height: 24),
                  ..._purchases(context, state),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _purchases(BuildContext context, InvoiceDetailState state) {
    final text = Theme.of(context).textTheme;

    if (state.status == InvoiceDetailStatus.failure) {
      return [
        Text(cardFailureMessage(state.failure!)),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => context.read<InvoiceDetailCubit>().reload(),
          child: const Text('Tentar de novo'),
        ),
      ];
    }
    if (state.status != InvoiceDetailStatus.loaded && state.transactions.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    return [
      SectionLabel('Compras · ${state.transactions.length}'),
      Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: state.transactions.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Nenhuma compra nesta fatura.', style: text.bodyMedium),
              )
            : Column(
                children: [
                  for (var i = 0; i < state.transactions.length; i++) ...[
                    if (i > 0) const Divider(indent: 16),
                    PurchaseRow(transaction: state.transactions[i]),
                  ],
                ],
              ),
      ),
    ];
  }
}
