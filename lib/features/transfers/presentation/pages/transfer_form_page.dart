import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/transfers/domain/entities/transfer_kind.dart';
import 'package:finly/features/transfers/presentation/cubit/transfer_form_cubit.dart';
import 'package:finly/features/transfers/presentation/cubit/transfer_form_state.dart';
import 'package:finly/features/transfers/presentation/exchange_rate.dart';
import 'package:finly/features/transfers/presentation/transfer_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Moves money out of an account of the active [workspace]. Pops with `true`
/// when the transfer was created.
///
/// - Same workspace: [accounts] gives both ends (at least two accounts).
/// - Between workspaces: the destination is an account of [otherWorkspace].
///   From Business it is a withdrawal, from Personal a contribution.
class TransferFormPage extends StatelessWidget {
  final WorkspaceEntity workspace;
  final List<AccountEntity> accounts;
  final WorkspaceEntity? otherWorkspace;

  const TransferFormPage({
    super.key,
    required this.workspace,
    required this.accounts,
    this.otherWorkspace,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TransferFormCubit>()..loadOtherAccounts(otherWorkspace?.id),
      child: _TransferFormView(
        workspace: workspace,
        accounts: accounts,
        otherWorkspace: otherWorkspace,
      ),
    );
  }
}

enum _Mode { internal, owner }

class _TransferFormView extends StatefulWidget {
  final WorkspaceEntity workspace;
  final List<AccountEntity> accounts;
  final WorkspaceEntity? otherWorkspace;

  const _TransferFormView({
    required this.workspace,
    required this.accounts,
    required this.otherWorkspace,
  });

  @override
  State<_TransferFormView> createState() => _TransferFormViewState();
}

class _TransferFormViewState extends State<_TransferFormView> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _received = TextEditingController();
  final _description = TextEditingController(text: 'Transferência');

  late _Mode _mode = _canInternal ? _Mode.internal : _Mode.owner;
  late String _fromId = widget.accounts.first.id;
  String? _toId;

  bool get _canInternal => widget.accounts.length >= 2;
  bool get _canOwner => widget.otherWorkspace != null;
  bool get _isBusiness => widget.workspace.type == WorkspaceType.business;

  TransferKind get _kind => _mode == _Mode.internal
      ? TransferKind.internal
      : (_isBusiness
          ? TransferKind.ownerWithdrawal
          : TransferKind.ownerContribution);

  AccountEntity get _from =>
      widget.accounts.firstWhere((account) => account.id == _fromId);

  List<AccountEntity> _destinations(TransferFormState state) {
    if (_mode == _Mode.internal) {
      return widget.accounts.where((account) => account.id != _fromId).toList();
    }
    return state.otherAccounts;
  }

  AccountEntity? _to(TransferFormState state) {
    for (final account in _destinations(state)) {
      if (account.id == _toId) return account;
    }
    return null;
  }

  @override
  void dispose() {
    _amount.dispose();
    _received.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final cubit = context.read<TransferFormCubit>();
    final to = _to(cubit.state);
    if (to == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Escolha a conta de destino.')),
        );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final from = _from;
    final amount = Money.tryParse(_amount.text, from.currency);
    if (amount == null || amount.cents <= 0) return;

    final crossCurrency = from.currency != to.currency;
    final received =
        crossCurrency ? Money.tryParse(_received.text, to.currency) : null;

    cubit.submit(
      fromAccountId: from.id,
      toAccountId: to.id,
      fromCurrency: from.currency,
      toCurrency: to.currency,
      amountCents: amount.cents,
      toAmountCents: received?.cents,
      description: _description.text,
      occurredAt: DateTime.now(),
      kind: _kind,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return BlocConsumer<TransferFormCubit, TransferFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == TransferFormStatus.failure && state.failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(transferFailureMessage(state.failure!))),
            );
        }
        if (state.status == TransferFormStatus.success) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final submitting = state.status == TransferFormStatus.submitting;

        Widget body;
        if (state.status == TransferFormStatus.loading) {
          body = const Center(child: CircularProgressIndicator());
        } else if (state.status == TransferFormStatus.loadFailed) {
          body = Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    transferFailureMessage(state.failure!),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context
                        .read<TransferFormCubit>()
                        .loadOtherAccounts(widget.otherWorkspace?.id),
                    child: const Text('Tentar de novo'),
                  ),
                ],
              ),
            ),
          );
        } else if (!_canInternal && !(_canOwner && state.otherAccounts.isNotEmpty)) {
          body = const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Para transferir você precisa de duas contas: no mesmo '
                'workspace ou uma em cada workspace.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        } else {
          body = _form(context, state, submitting, text);
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Nova transferência')),
          body: SafeArea(child: body),
        );
      },
    );
  }

  Widget _form(
    BuildContext context,
    TransferFormState state,
    bool submitting,
    TextTheme text,
  ) {
    final from = _from;
    final to = _to(state);
    final destinations = _destinations(state);
    final crossCurrency = to != null && from.currency != to.currency;
    final ownerAvailable = _canOwner && state.otherAccounts.isNotEmpty;
    final ownerLabel = _isBusiness ? 'Retirada' : 'Aporte';

    // The exchange rate the two typed amounts imply, to catch a typo.
    String? rate;
    if (crossCurrency) {
      final sent = Money.tryParse(_amount.text, from.currency);
      final got = Money.tryParse(_received.text, to.currency);
      if (sent != null && got != null) {
        rate = exchangeRateLabel(
          fromCurrency: from.currency,
          toCurrency: to.currency,
          fromCents: sent.cents,
          toCents: got.cents,
        );
      }
    }

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_canInternal && ownerAvailable)
                  SegmentedButton<_Mode>(
                    segments: [
                      const ButtonSegment(
                        value: _Mode.internal,
                        label: Text('Mesmo workspace'),
                      ),
                      ButtonSegment(value: _Mode.owner, label: Text(ownerLabel)),
                    ],
                    selected: {_mode},
                    onSelectionChanged: submitting
                        ? null
                        : (selection) => setState(() {
                              _mode = selection.first;
                              _toId = null;
                            }),
                  )
                else if (_mode == _Mode.owner)
                  Text(
                    '$ownerLabel para ${widget.otherWorkspace?.name ?? ''}',
                    style: text.titleMedium,
                  )
                else
                  Text('Entre contas deste workspace', style: text.titleMedium),
                if (_mode == _Mode.owner) ...[
                  const SizedBox(height: 8),
                  Text(
                    _isBusiness
                        ? 'Retirada: o dinheiro sai da empresa e entra no seu '
                            'workspace pessoal.'
                        : 'Aporte: o dinheiro sai do seu workspace pessoal e '
                            'entra na empresa.',
                    style: text.bodySmall,
                  ),
                ],
                const SizedBox(height: 20),
                Text('De', style: text.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final account in widget.accounts)
                      ChoiceChip(
                        label: Text('${account.name} (${account.currency})'),
                        selected: _fromId == account.id,
                        onSelected: submitting
                            ? null
                            : (_) => setState(() {
                                  _fromId = account.id;
                                  if (_toId == account.id) _toId = null;
                                }),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  _mode == _Mode.owner
                      ? 'Para (${widget.otherWorkspace?.name ?? ''})'
                      : 'Para',
                  style: text.labelLarge,
                ),
                const SizedBox(height: 8),
                if (destinations.isEmpty)
                  Text('Nenhuma conta disponível.', style: text.bodyMedium)
                else
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final account in destinations)
                        ChoiceChip(
                          label: Text('${account.name} (${account.currency})'),
                          selected: _toId == account.id,
                          onSelected: submitting
                              ? null
                              : (_) => setState(() => _toId = account.id),
                        ),
                    ],
                  ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _amount,
                  enabled: !submitting,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Valor que sai (${from.currency})',
                    prefixText: '${Money.symbolFor(from.currency)} ',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final amount = Money.tryParse(value ?? '', from.currency);
                    return (amount == null || amount.cents <= 0)
                        ? 'Informe um valor maior que zero (ex.: 150,00).'
                        : null;
                  },
                ),
                if (crossCurrency) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _received,
                    enabled: !submitting,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Valor que chega (${to.currency})',
                      prefixText: '${Money.symbolFor(to.currency)} ',
                      helperText:
                          'As moedas são diferentes: informe os dois valores.',
                      helperMaxLines: 2,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final amount = Money.tryParse(value ?? '', to.currency);
                      return (amount == null || amount.cents <= 0)
                          ? 'Informe o valor recebido.'
                          : null;
                    },
                  ),
                  if (rate != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(rate, style: text.titleSmall),
                    ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  enabled: !submitting,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final description = (value ?? '').trim();
                    if (description.isEmpty || description.length > 200) {
                      return 'Informe uma descrição (até 200 caracteres).';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: submitting ? null : _submit,
                  child: submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Transferir'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}