import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/presentation/account_messages.dart';
import 'package:finly/features/accounts/presentation/account_style.dart';
import 'package:finly/features/accounts/presentation/cubit/account_form_cubit.dart';
import 'package:finly/features/accounts/presentation/cubit/account_form_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Creates an account in [workspaceId]. Pops with `true` when it was created.
class AccountFormPage extends StatelessWidget {
  final String workspaceId;

  const AccountFormPage({super.key, required this.workspaceId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AccountFormCubit>(),
      child: _AccountFormView(workspaceId: workspaceId),
    );
  }
}

class _AccountFormView extends StatefulWidget {
  final String workspaceId;

  const _AccountFormView({required this.workspaceId});

  @override
  State<_AccountFormView> createState() => _AccountFormViewState();
}

class _AccountFormViewState extends State<_AccountFormView> {
  static const _types = [
    AccountType.checking,
    AccountType.savings,
    AccountType.investment,
  ];
  static const _currencies = ['BRL', 'USD', 'EUR'];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _balance = TextEditingController(text: '0,00');
  AccountType _type = AccountType.checking;
  String _currency = 'BRL';

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final balance = Money.tryParse(_balance.text, _currency);
    if (balance == null) return;

    context.read<AccountFormCubit>().submit(
          workspaceId: widget.workspaceId,
          name: _name.text,
          type: _type,
          currency: _currency,
          openingBalanceCents: balance.cents,
        );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return BlocConsumer<AccountFormCubit, AccountFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == AccountFormStatus.failure && state.failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(accountFailureMessage(state.failure!))),
            );
        }
        if (state.status == AccountFormStatus.success) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final submitting = state.status == AccountFormStatus.submitting;

        return Scaffold(
          appBar: AppBar(title: const Text('Nova conta')),
          body: SafeArea(
            child: Center(
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
                        TextFormField(
                          controller: _name,
                          enabled: !submitting,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nome da conta',
                            hintText: 'Ex.: Nubank, Carteira',
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
                        const SizedBox(height: 20),
                        Text('Tipo', style: text.labelLarge),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final type in _types)
                              ChoiceChip(
                                label: Text(accountTypeLabel(type)),
                                selected: _type == type,
                                onSelected: submitting
                                    ? null
                                    : (_) => setState(() => _type = type),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text('Moeda', style: text.labelLarge),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final currency in _currencies)
                              ChoiceChip(
                                label: Text(currency),
                                selected: _currency == currency,
                                onSelected: submitting
                                    ? null
                                    : (_) =>
                                        setState(() => _currency = currency),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _balance,
                          enabled: !submitting,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,\-]'),
                            ),
                          ],
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Saldo inicial',
                            prefixText: '${Money.symbolFor(_currency)} ',
                            helperText: 'Saldo da conta hoje. Pode ser negativo.',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              Money.tryParse(value ?? '', _currency) == null
                                  ? 'Informe um valor válido (ex.: 1.234,56).'
                                  : null,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: submitting ? null : _submit,
                          child: submitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Criar conta'),
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