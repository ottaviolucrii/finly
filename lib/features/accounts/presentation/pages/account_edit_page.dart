import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/presentation/account_messages.dart';
import 'package:finly/features/accounts/presentation/account_style.dart';
import 'package:finly/features/accounts/presentation/cubit/account_edit_cubit.dart';
import 'package:finly/features/accounts/presentation/cubit/account_edit_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Renames an account and corrects its opening balance. The type and the
/// currency are shown but never change. Pops with `true` when saved.
class AccountEditPage extends StatelessWidget {
  final AccountEntity account;

  const AccountEditPage({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AccountEditCubit>(),
      child: _AccountEditView(account: account),
    );
  }
}

class _AccountEditView extends StatefulWidget {
  final AccountEntity account;

  const _AccountEditView({required this.account});

  @override
  State<_AccountEditView> createState() => _AccountEditViewState();
}

class _AccountEditViewState extends State<_AccountEditView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.account.name);
  late final TextEditingController _opening = TextEditingController(
    text: _isCard
        ? ''
        : Money(widget.account.openingBalanceCents, widget.account.currency)
            .format(withSymbol: false),
  );

  bool get _isCard => widget.account.type == AccountType.creditCard;

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    int? opening;
    if (!_isCard) {
      final parsed = Money.tryParse(_opening.text, widget.account.currency);
      if (parsed == null) return;
      opening = parsed.cents;
    }

    context.read<AccountEditCubit>().submit(
          accountId: widget.account.id,
          name: _name.text,
          openingBalanceCents: opening,
        );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final account = widget.account;

    return BlocConsumer<AccountEditCubit, AccountEditState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == AccountEditStatus.failure && state.failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(accountFailureMessage(state.failure!))),
            );
        }
        if (state.status == AccountEditStatus.success) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final submitting = state.status == AccountEditStatus.submitting;

        return Scaffold(
          appBar: AppBar(title: const Text('Editar conta')),
          body: SafeArea(
            child: Align(
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
                        Text(
                          '${accountTypeLabel(account.type)} · ${account.currency}',
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'O tipo e a moeda não podem ser alterados: há '
                          'lançamentos que dependem deles.',
                          style: text.bodySmall,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _name,
                          enabled: !submitting,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction:
                              _isCard ? TextInputAction.done : TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nome da conta',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final name = (value ?? '').trim();
                            if (name.isEmpty || name.length > 80) {
                              return 'Informe um nome (até 80 caracteres).';
                            }
                            return null;
                          },
                        ),
                        if (!_isCard) ...[
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _opening,
                            enabled: !submitting,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]')),
                            ],
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: 'Saldo inicial',
                              prefixText: '${Money.symbolFor(account.currency)} ',
                              helperText: 'O saldo atual é o saldo inicial mais '
                                  'as movimentações. Mudar o saldo inicial muda '
                                  'o saldo atual pelo mesmo valor.',
                              helperMaxLines: 4,
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final parsed =
                                  Money.tryParse(value ?? '', account.currency);
                              return parsed == null
                                  ? 'Informe um valor válido (ex.: 1.500,00).'
                                  : null;
                            },
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          Text(
                            'Limite, fechamento e vencimento do cartão ficam na '
                            'tela Cartões.',
                            style: text.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: submitting ? null : _submit,
                          child: submitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Salvar alterações'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}