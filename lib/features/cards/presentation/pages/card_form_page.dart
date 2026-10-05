import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/features/cards/presentation/card_messages.dart';
import 'package:finly/features/cards/presentation/cubit/card_form_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/card_form_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const _currencies = ['BRL', 'USD', 'EUR'];

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

  /// A day of the month from 1 to 31, or null.
  int? _day(String text) {
    final value = int.tryParse(text.trim());
    return (value != null && value >= 1 && value <= 31) ? value : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final limit = Money.tryParse(_limit.text, _currency);
    final closing = _day(_closing.text);
    final due = _day(_due.text);
    if (limit == null || limit.cents <= 0 || closing == null || due == null) {
      return;
    }

    context.read<CardFormCubit>().submit(
          workspaceId: widget.workspaceId,
          name: _name.text,
          currency: _currency,
          limitCents: limit.cents,
          closingDay: closing,
          dueDay: due,
        );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

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

        return Scaffold(
          appBar: AppBar(title: const Text('Novo cartão')),
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
                        TextFormField(
                          controller: _name,
                          enabled: !submitting,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nome do cartão',
                            hintText: 'Ex.: Nubank, Visa Empresa',
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
                          controller: _limit,
                          enabled: !submitting,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                          ],
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Limite',
                            prefixText: '${Money.symbolFor(_currency)} ',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final limit = Money.tryParse(value ?? '', _currency);
                            return (limit == null || limit.cents <= 0)
                                ? 'Informe um limite maior que zero.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _closing,
                                enabled: !submitting,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(2),
                                ],
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Fecha no dia',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) => _day(value ?? '') == null
                                    ? 'De 1 a 31.'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _due,
                                enabled: !submitting,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(2),
                                ],
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                  labelText: 'Vence no dia',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) => _day(value ?? '') == null
                                    ? 'De 1 a 31.'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Em meses mais curtos, o dia 31 vale o último dia do mês.',
                          style: text.bodySmall,
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
                              : const Text('Criar cartão'),
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