import 'package:finly/core/di/injection.dart';
import 'package:finly/core/utils/cents_input_formatter.dart';
import 'package:finly/core/widgets/form_parts.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/transfers/domain/entities/transfer_kind.dart';
import 'package:finly/features/transfers/presentation/cubit/transfer_form_cubit.dart';
import 'package:finly/features/transfers/presentation/cubit/transfer_form_state.dart';
import 'package:finly/features/transfers/presentation/exchange_rate.dart';
import 'package:finly/features/transfers/presentation/transfer_messages.dart';
import 'package:flutter/material.dart';
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
    final amount = centsFromInput(_amount.text);
    if (amount <= 0) return;

    final crossCurrency = from.currency != to.currency;
    final received =
        crossCurrency ? centsFromInput(_received.text) : null;

    cubit.submit(
      fromAccountId: from.id,
      toAccountId: to.id,
      fromCurrency: from.currency,
      toCurrency: to.currency,
      amountCents: amount,
      toAmountCents: received,
      description: _description.text,
      occurredAt: DateTime.now(),
      kind: _kind,
    );
  }

  @override
  Widget build(BuildContext context) {
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

        Widget plain(Widget body) => Scaffold(
              appBar: AppBar(title: const Text('Nova transferência')),
              body: SafeArea(child: body),
            );

        if (state.status == TransferFormStatus.loading) {
          return plain(const Center(child: CircularProgressIndicator()));
        }
        if (state.status == TransferFormStatus.loadFailed) {
          return plain(
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(transferFailureMessage(state.failure!), textAlign: TextAlign.center),
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
            ),
          );
        }
        if (!_canInternal && !(_canOwner && state.otherAccounts.isNotEmpty)) {
          return plain(
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Para transferir você precisa de duas contas: no mesmo workspace ou uma em cada workspace.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return FormPage(
          title: 'Nova transferência',
          saveLabel: 'Transferir',
          saving: submitting,
          onSave: _submit,
          form: _form(context, state, submitting),
        );
      },
    );
  }

  Widget _form(BuildContext context, TransferFormState state, bool submitting) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final from = _from;
    final to = _to(state);
    final destinations = _destinations(state);
    final crossCurrency = to != null && from.currency != to.currency;
    final ownerAvailable = _canOwner && state.otherAccounts.isNotEmpty;
    final ownerLabel = _isBusiness ? 'Retirada' : 'Aporte';

    // The exchange rate the two typed amounts imply, to catch a typo.
    String? rate;
    if (crossCurrency) {
      final sent = centsFromInput(_amount.text);
      final got = centsFromInput(_received.text);
      if (sent > 0 && got > 0) {
        rate = exchangeRateLabel(
          fromCurrency: from.currency,
          toCurrency: to.currency,
          fromCents: sent,
          toCents: got,
        );
      }
    }

    PillOption<String> account(AccountEntity a) => PillOption(a.id, '${a.name} (${a.currency})');

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_canInternal && ownerAvailable) ...[
            ChoicePills<_Mode>(
              options: [
                const PillOption(_Mode.internal, 'Entre minhas contas', icon: Icons.swap_horiz),
                PillOption(_Mode.owner, ownerLabel, icon: Icons.business_center_outlined),
              ],
              selected: _mode,
              onSelected: submitting
                  ? null
                  : (mode) => setState(() {
                        _mode = mode;
                        _toId = null;
                      }),
            ),
            formGap,
          ],
          if (_mode == _Mode.owner) ...[
            InfoBox(
              icon: Icons.business_center_outlined,
              text: _isBusiness
                  ? 'Retirada para ${widget.otherWorkspace?.name ?? ''}: o dinheiro sai da empresa e entra '
                      'no seu workspace pessoal.'
                  : 'Aporte para ${widget.otherWorkspace?.name ?? ''}: o dinheiro sai do seu workspace '
                      'pessoal e entra na empresa.',
            ),
            formGap,
          ],
          AmountCard(
            label: 'Valor que sai (${from.currency})',
            controller: _amount,
            currency: from.currency,
            enabled: !submitting,
            onChanged: (_) => setState(() {}),
            validator: (value) => centsFromInput(value ?? '') <= 0
                ? 'Informe um valor maior que zero.'
                : null,
          ),
          formGap,
          const FieldLabel('De'),
          ChoicePills<String>(
            options: [for (final a in widget.accounts) account(a)],
            selected: _fromId,
            onSelected: submitting
                ? null
                : (id) => setState(() {
                      _fromId = id;
                      if (_toId == id) _toId = null;
                    }),
          ),
          formGap,
          FieldLabel(_mode == _Mode.owner ? 'Para (${widget.otherWorkspace?.name ?? ''})' : 'Para'),
          if (destinations.isEmpty)
            Text('Nenhuma conta disponível.', style: text.bodyMedium)
          else
            ChoicePills<String>(
              options: [for (final a in destinations) account(a)],
              selected: _toId,
              onSelected: submitting ? null : (id) => setState(() => _toId = id),
            ),
          if (crossCurrency) ...[
            formGap,
            AmountCard(
              label: 'Valor que chega (${to.currency})',
              controller: _received,
              currency: to.currency,
              enabled: !submitting,
              onChanged: (_) => setState(() {}),
              validator: (value) => centsFromInput(value ?? '') <= 0 ? 'Informe o valor recebido.' : null,
              footer: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  rate ?? 'As moedas são diferentes: informe os dois valores.',
                  textAlign: TextAlign.center,
                  style: rate == null
                      ? text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)
                      : text.titleSmall,
                ),
              ),
            ),
          ],
          formGap,
          const FieldLabel('Descrição'),
          TextFormField(
            controller: _description,
            enabled: !submitting,
            textCapitalization: TextCapitalization.sentences,
            decoration: formFieldDecoration(context),
            validator: (value) {
              final description = (value ?? '').trim();
              if (description.isEmpty || description.length > 200) {
                return 'Informe uma descrição (até 200 caracteres).';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
