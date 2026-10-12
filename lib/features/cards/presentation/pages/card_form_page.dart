import 'package:finly/core/di/injection.dart';
import 'package:finly/core/utils/cents_input_formatter.dart';
import 'package:finly/core/widgets/form_parts.dart';
import 'package:finly/core/widgets/form_validation.dart';
import 'package:finly/features/cards/presentation/card_messages.dart';
import 'package:finly/features/cards/presentation/cubit/card_form_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/card_form_state.dart';
import 'package:finly/features/cards/presentation/widgets/card_days_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Creates a credit card in [workspaceId]. Pops with `true` when created.
class CardFormPage extends StatelessWidget {
  final String workspaceId;

  const CardFormPage({super.key, required this.workspaceId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CardFormCubit>(),
      child: _CardFormView(workspaceId: workspaceId),
    );
  }
}

class _CardFormView extends StatefulWidget {
  final String workspaceId;

  const _CardFormView({required this.workspaceId});

  @override
  State<_CardFormView> createState() => _CardFormViewState();
}

class _CardFormViewState extends State<_CardFormView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _limit = TextEditingController();
  final _closing = TextEditingController();
  final _due = TextEditingController();
  String _currency = 'BRL';

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    _closing.dispose();
    _due.dispose();
    super.dispose();
  }

  void _submit() {
    if (!validateOnSave(_formKey)) return;
    final limit = centsFromInput(_limit.text);
    final closing = dayOfMonth(_closing.text);
    final due = dayOfMonth(_due.text);
    if (limit <= 0 || closing == null || due == null) {
      return;
    }

    context.read<CardFormCubit>().submit(
          workspaceId: widget.workspaceId,
          name: _name.text,
          currency: _currency,
          limitCents: limit,
          closingDay: closing,
          dueDay: due,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CardFormCubit, CardFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == CardFormStatus.failure && state.failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(cardFailureMessage(state.failure!))),
            );
        }
        if (state.status == CardFormStatus.success) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final submitting = state.status == CardFormStatus.submitting;

        return FormPage(
          title: 'Novo cartão',
          saveLabel: 'Criar cartão',
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
                  decoration: formFieldDecoration(context, hint: 'Ex.: Nubank, Visa Empresa'),
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
                  validator: (value) => centsFromInput(value ?? '') <= 0
                      ? 'Informe um limite maior que zero.'
                      : null,
                ),
                formGap,
                CardDaysFields(closing: _closing, due: _due, enabled: !submitting),
                formGap,
                const FieldLabel('Moeda'),
                ChoicePills<String>(
                  options: currencyPills,
                  selected: _currency,
                  onSelected: submitting ? null : (currency) => setState(() => _currency = currency),
                ),
                formGap,
                const InfoBox(
                  icon: Icons.calendar_today_outlined,
                  text: 'Em meses mais curtos, o dia 31 vale o último dia do mês.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
