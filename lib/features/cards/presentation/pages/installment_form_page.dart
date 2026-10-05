import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/cards/domain/entities/credit_card_entity.dart';
import 'package:finly/features/cards/domain/installment_split.dart';
import 'package:finly/features/cards/presentation/card_messages.dart';
import 'package:finly/features/cards/presentation/cubit/installment_form_cubit.dart';
import 'package:finly/features/cards/presentation/cubit/installment_form_state.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A purchase on [card] split into installments. Pops with `true` when saved.
class InstallmentFormPage extends StatelessWidget {
  final CreditCardEntity card;

  const InstallmentFormPage({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<InstallmentFormCubit>()..loadCategories(card.workspaceId),
      child: _InstallmentFormView(card: card),
    );
  }
}

class _InstallmentFormView extends StatefulWidget {
  final CreditCardEntity card;

  const _InstallmentFormView({required this.card});

  @override
  State<_InstallmentFormView> createState() => _InstallmentFormViewState();
}

class _InstallmentFormViewState extends State<_InstallmentFormView> {
  static const _quickCounts = [2, 3, 4, 6, 10, 12];

  final _formKey = GlobalKey<FormState>();
  final _total = TextEditingController();
  final _count = TextEditingController(text: '2');
  final _description = TextEditingController();
  String? _categoryId;
  DateTime _date = DateTime.now();

  String get _currency => widget.card.currency;

  /// Today keeps the current time; another day is recorded at noon.
  DateTime get _purchaseAt {
    final now = DateTime.now();
    final isToday =
        _date.year == now.year && _date.month == now.month && _date.day == now.day;
    return isToday ? now : DateTime(_date.year, _date.month, _date.day, 12);
  }

  @override
  void dispose() {
    _total.dispose();
    _count.dispose();
    _description.dispose();
    super.dispose();
  }

  int? _parsedCount() {
    final value = int.tryParse(_count.text.trim());
    return (value != null && value >= 2 && value <= 48) ? value : null;
  }

  /// "3× de R$ 333,33" or "1ª de R$ 333,35 e 2× de R$ 333,33".
  String? _preview() {
    final total = Money.tryParse(_total.text, _currency);
    final count = _parsedCount();
    if (total == null || count == null || total.cents < count) return null;

    final parts = splitInstallments(total.cents, count);
    final first = Money(parts.first, _currency).format();
    final rest = Money(parts.last, _currency).format();
    if (parts.first == parts.last) return '$count× de $first';
    return '1ª de $first e ${count - 1}× de $rest';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final total = Money.tryParse(_total.text, _currency);
    final count = _parsedCount();
    if (total == null || count == null) return;

    context.read<InstallmentFormCubit>().submit(
          accountId: widget.card.accountId,
          categoryId: _categoryId,
          totalCents: total.cents,
          installments: count,
          description: _description.text,
          purchaseAt: _purchaseAt,
        );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return BlocConsumer<InstallmentFormCubit, InstallmentFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == InstallmentFormStatus.failure &&
            state.failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(cardFailureMessage(state.failure!))),
            );
        }
        if (state.status == InstallmentFormStatus.success) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final submitting = state.status == InstallmentFormStatus.submitting;

        Widget body;
        if (state.status == InstallmentFormStatus.loading) {
          body = const Center(child: CircularProgressIndicator());
        } else if (state.status == InstallmentFormStatus.loadFailed) {
          body = Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cardFailureMessage(state.failure!),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context
                        .read<InstallmentFormCubit>()
                        .loadCategories(widget.card.workspaceId),
                    child: const Text('Tentar de novo'),
                  ),
                ],
              ),
            ),
          );
        } else {
          body = _form(state, submitting, text);
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Compra parcelada')),
          body: SafeArea(child: body),
        );
      },
    );
  }

  Widget _form(InstallmentFormState state, bool submitting, TextTheme text) {
    final preview = _preview();

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
                Text(widget.card.name, style: text.titleMedium),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _total,
                  enabled: !submitting,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Valor total da compra',
                    prefixText: '${Money.symbolFor(_currency)} ',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final total = Money.tryParse(value ?? '', _currency);
                    return (total == null || total.cents <= 0)
                        ? 'Informe um valor maior que zero (ex.: 1.200,00).'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _count,
                  enabled: !submitting,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Número de parcelas',
                    helperText: 'De 2 a 48.',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      _parsedCount() == null ? 'Informe de 2 a 48 parcelas.' : null,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final count in _quickCounts)
                      ActionChip(
                        label: Text('${count}x'),
                        onPressed: submitting
                            ? null
                            : () => setState(() => _count.text = '$count'),
                      ),
                  ],
                ),
                if (preview != null) ...[
                  const SizedBox(height: 12),
                  Text(preview, style: text.titleMedium),
                  Text(
                    'A primeira parcela fica com os centavos que sobram.',
                    style: text.bodySmall,
                  ),
                ],
                const SizedBox(height: 20),
                Text('Categoria', style: text.labelLarge),
                const SizedBox(height: 8),
                if (state.categories.isEmpty)
                  Text('Nenhuma categoria disponível.', style: text.bodyMedium)
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final category in state.categories)
                        ChoiceChip(
                          avatar: Icon(categoryIcon(category.icon), size: 18),
                          label: Text(category.name),
                          selected: _categoryId == category.id,
                          onSelected: submitting
                              ? null
                              : (selected) => setState(
                                    () => _categoryId =
                                        selected ? category.id : null,
                                  ),
                        ),
                    ],
                  ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _description,
                  enabled: !submitting,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    hintText: 'Ex.: Geladeira, Notebook',
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
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: const Text('Data da compra'),
                  subtitle: Text(formatDateBr(_date)),
                  onTap: submitting ? null : _pickDate,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: submitting ? null : _submit,
                  child: submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar compra'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}