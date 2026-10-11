import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/cents_input_formatter.dart';
import 'package:finly/core/widgets/form_parts.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/accounts/domain/entities/account_type.dart';
import 'package:finly/features/accounts/presentation/account_messages.dart';
import 'package:finly/features/accounts/presentation/account_style.dart';
import 'package:finly/features/accounts/presentation/cubit/account_edit_cubit.dart';
import 'package:finly/features/accounts/presentation/cubit/account_edit_state.dart';
import 'package:flutter/material.dart';
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
  late final TextEditingController _name = TextEditingController(text: widget.account.name);

  /// The opening balance without its sign (the sign is in [_negative]).
  late final TextEditingController _opening = TextEditingController(
    text: _isCard
        ? ''
        : Money(widget.account.openingBalanceCents.abs(), widget.account.currency).format(withSymbol: false),
  );
  late bool _negative = widget.account.openingBalanceCents < 0;

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
      final cents = centsFromInput(_opening.text);
      opening = _negative ? -cents : cents;
    }

    context.read<AccountEditCubit>().submit(
          accountId: widget.account.id,
          name: _name.text,
          openingBalanceCents: opening,
        );
  }

  @override
  Widget build(BuildContext context) {
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

        return FormPage(
          title: 'Editar conta',
          saveLabel: 'Salvar alterações',
          saving: submitting,
          onSave: _submit,
          form: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FieldLabel('Nome'),
                TextFormField(
                  controller: _name,
                  enabled: !submitting,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  decoration: formFieldDecoration(context),
                  validator: (value) {
                    final name = (value ?? '').trim();
                    if (name.isEmpty || name.length > 80) {
                      return 'Informe um nome (até 80 caracteres).';
                    }
                    return null;
                  },
                ),
                formGap,
                InfoBox(
                  icon: Icons.lock_outline,
                  text: '${accountTypeLabel(account.type)} · ${account.currency}. O tipo e a moeda '
                      'não podem ser alterados: há lançamentos que dependem deles.',
                ),
                formGap,
                if (_isCard)
                  const InfoBox(
                    icon: Icons.credit_card,
                    text: 'Limite, fechamento e vencimento do cartão ficam na tela Cartões.',
                  )
                else ...[
                  AmountCard(
                    label: 'Saldo inicial',
                    controller: _opening,
                    currency: account.currency,
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
                  const InfoBox(
                    icon: Icons.info_outline,
                    text: 'O saldo atual é o saldo inicial mais as movimentações. '
                        'Mudar o saldo inicial muda o saldo atual pelo mesmo valor.',
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
