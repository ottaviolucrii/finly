import 'package:finly/core/di/injection.dart';
import 'package:finly/core/utils/cents_input_formatter.dart';
import 'package:finly/core/widgets/form_parts.dart';
import 'package:finly/core/widgets/form_validation.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/presentation/account_messages.dart';
import 'package:finly/features/accounts/presentation/account_style.dart';
import 'package:finly/features/accounts/presentation/cubit/account_form_cubit.dart';
import 'package:finly/features/accounts/presentation/cubit/account_form_state.dart';
import 'package:flutter/material.dart';
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

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _balance = TextEditingController();
  AccountType _type = AccountType.checking;
  String _currency = 'BRL';

  /// The balance of today is below zero (an account in overdraft).
  bool _negative = false;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  void _submit() {
    if (!validateOnSave(_formKey)) return;
    final cents = centsFromInput(_balance.text);

    context.read<AccountFormCubit>().submit(
          workspaceId: widget.workspaceId,
          name: _name.text,
          type: _type,
          currency: _currency,
          openingBalanceCents: _negative ? -cents : cents,
        );
  }

  @override
  Widget build(BuildContext context) {
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

        return FormPage(
          title: 'Nova conta',
          saveLabel: 'Criar conta',
          saving: submitting,
          onSave: _submit,
          form: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.disabled,
            onChanged: () => revalidateIfTried(_formKey),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FieldLabel('Nome'),
                TextFormField(
                  controller: _name,
                  enabled: !submitting,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: formFieldDecoration(context, hint: 'Ex.: Nubank, Carteira'),
                  validator: (value) {
                    final name = (value ?? '').trim();
                    if (name.isEmpty || name.length > 80) {
                      return 'Informe um nome (até 80 caracteres).';
                    }
                    return null;
                  },
                ),
                formGap,
                const FieldLabel('Tipo'),
                ChoicePills<AccountType>(
                  options: [
                    for (final type in _types)
                      PillOption(type, accountTypeLabel(type), icon: accountTypeIcon(type)),
                  ],
                  selected: _type,
                  onSelected: submitting ? null : (type) => setState(() => _type = type),
                ),
                formGap,
                AmountCard(
                  label: 'Saldo de hoje',
                  controller: _balance,
                  currency: _currency,
                  enabled: !submitting,
                  footer: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ChoicePills<bool>(
                      options: const [PillOption(false, 'Positivo'), PillOption(true, 'Negativo')],
                      selected: _negative,
                      onSelected: submitting ? null : (value) => setState(() => _negative = value),
                    ),
                  ),
                ),
                formGap,
                const FieldLabel('Moeda'),
                ChoicePills<String>(
                  options: currencyPills,
                  selected: _currency,
                  onSelected: submitting ? null : (currency) => setState(() => _currency = currency),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
