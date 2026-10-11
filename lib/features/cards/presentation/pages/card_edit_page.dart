import 'package:finly/core/di/injection.dart';
import 'package:finly/core/utils/cents_input_formatter.dart';
import 'package:finly/core/widgets/form_parts.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/presentation/card_messages.dart';
import 'package:finly/features/cards/presentation/cubit/card_edit_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/card_edit_state.dart';
import 'package:finly/features/cards/presentation/widgets/card_days_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Edits a card's name, limit and closing and due days. The currency is shown
/// but never changes. Pops with `true` when saved.
class CardEditPage extends StatelessWidget {
  final CreditCardEntity card;

  const CardEditPage({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CardEditCubit>(),
      child: _CardEditView(card: card),
    );
  }
}

class _CardEditView extends StatefulWidget {
  final CreditCardEntity card;

  const _CardEditView({required this.card});

  @override
  State<_CardEditView> createState() => _CardEditViewState();
}

class _CardEditViewState extends State<_CardEditView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.card.name);
  late final TextEditingController _limit = TextEditingController(
    text: widget.card.limit.format(withSymbol: false),
  );
  late final TextEditingController _closing =
      TextEditingController(text: '${widget.card.closingDay}');
  late final TextEditingController _due =
      TextEditingController(text: '${widget.card.dueDay}');

  String get _currency => widget.card.currency;

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    _closing.dispose();
    _due.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final limit = centsFromInput(_limit.text);
    final closing = dayOfMonth(_closing.text);
    final due = dayOfMonth(_due.text);
    if (limit <= 0 || closing == null || due == null) {
      return;
    }

    context.read<CardEditCubit>().submit(
          accountId: widget.card.accountId,
          name: _name.text,
          limitCents: limit,
          closingDay: closing,
          dueDay: due,
        );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final newLimit = centsFromInput(_limit.text);
    final belowUsed = newLimit > 0 && newLimit < widget.card.usedCents;

    return BlocConsumer<CardEditCubit, CardEditState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == CardEditStatus.failure && state.failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(cardFailureMessage(state.failure!))),
            );
        }
        if (state.status == CardEditStatus.success) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final submitting = state.status == CardEditStatus.submitting;

        return FormPage(
          title: 'Editar cartão',
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
                  textInputAction: TextInputAction.next,
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
                AmountCard(
                  label: 'Limite',
                  controller: _limit,
                  currency: _currency,
                  enabled: !submitting,
                  onChanged: (_) => setState(() {}),
                  validator: (value) => centsFromInput(value ?? '') <= 0
                      ? 'Informe um limite maior que zero.'
                      : null,
                  footer: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      belowUsed
                          ? 'O novo limite é menor que o valor em uso (${widget.card.used.format()}): '
                              'o cartão ficará acima do limite.'
                          : 'Em uso agora: ${widget.card.used.format()}',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(
                        color: belowUsed ? scheme.error : scheme.onSurfaceVariant,
                        fontWeight: belowUsed ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                ),
                formGap,
                CardDaysFields(closing: _closing, due: _due, enabled: !submitting),
                formGap,
                const InfoBox(
                  icon: Icons.calendar_today_outlined,
                  text: 'Os novos dias de fechamento e vencimento valem para as próximas compras. '
                      'As faturas que já existem mantêm suas datas.',
                ),
                const SizedBox(height: 12),
                InfoBox(
                  icon: Icons.lock_outline,
                  text: 'Moeda: $_currency. Ela não pode ser alterada: há lançamentos que dependem dela.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
