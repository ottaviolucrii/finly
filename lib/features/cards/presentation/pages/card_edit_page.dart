import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/presentation/card_messages.dart';
import 'package:finly/features/cards/presentation/cubit/card_edit_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/card_edit_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    context.read<CardEditCubit>().submit(
          accountId: widget.card.accountId,
          name: _name.text,
          limitCents: limit.cents,
          closingDay: closing,
          dueDay: due,
        );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final newLimit = Money.tryParse(_limit.text, _currency);
    final belowUsed =
        newLimit != null && newLimit.cents < widget.card.usedCents;

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

        return Scaffold(
          appBar: AppBar(title: const Text('Editar cartão')),
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
                        Text('Moeda: $_currency', style: text.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'A moeda não pode ser alterada: há lançamentos que '
                          'dependem dela.',
                          style: text.bodySmall,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _name,
                          enabled: !submitting,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nome do cartão',
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
                        TextFormField(
                          controller: _limit,
                          enabled: !submitting,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                          ],
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(() {}),
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
                        if (belowUsed)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'O novo limite é menor que o valor em uso '
                              '(${widget.card.used.format()}): o cartão ficará '
                              'acima do limite.',
                              style: text.bodySmall?.copyWith(
                                color: scheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
                          'Os novos dias de fechamento e vencimento valem para '
                          'as próximas compras. As faturas que já existem '
                          'mantêm suas datas.',
                          style: text.bodySmall,
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