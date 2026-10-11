import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/cents_input_formatter.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/core/widgets/form_parts.dart';
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
    final total = centsFromInput(_total.text);
    final count = _parsedCount();
    if (count == null || total < count) return null;

    final parts = splitInstallments(total, count);
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
    final total = centsFromInput(_total.text);
    final count = _parsedCount();
    if (total <= 0 || count == null) return;

    context.read<InstallmentFormCubit>().submit(
          accountId: widget.card.accountId,
          categoryId: _categoryId,
          totalCents: total,
          installments: count,
          description: _description.text,
          purchaseAt: _purchaseAt,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InstallmentFormCubit, InstallmentFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == InstallmentFormStatus.failure && state.failure != null) {
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

        if (state.status == InstallmentFormStatus.loading) {
          return Scaffold(
            appBar: AppBar(title: const Text('Compra parcelada')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (state.status == InstallmentFormStatus.loadFailed) {
          return Scaffold(
            appBar: AppBar(title: const Text('Compra parcelada')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(cardFailureMessage(state.failure!), textAlign: TextAlign.center),
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
            ),
          );
        }

        return FormPage(
          title: 'Compra parcelada',
          saveLabel: 'Salvar compra',
          saving: submitting,
          onSave: _submit,
          form: _form(context, state, submitting),
        );
      },
    );
  }

  Widget _form(BuildContext context, InstallmentFormState state, bool submitting) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final preview = _preview();
    final count = _parsedCount();

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoBox(icon: Icons.credit_card, text: 'No cartão ${widget.card.name}.'),
          formGap,
          AmountCard(
            label: 'Valor total da compra',
            controller: _total,
            currency: _currency,
            enabled: !submitting,
            onChanged: (_) => setState(() {}),
            validator: (value) => centsFromInput(value ?? '') <= 0
                ? 'Informe um valor maior que zero.'
                : null,
            footer: preview == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      preview,
                      textAlign: TextAlign.center,
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: scheme.primary),
                    ),
                  ),
          ),
          formGap,
          const FieldLabel('Parcelas'),
          ChoicePills<int>(
            options: [for (final quick in _quickCounts) PillOption(quick, '$quick×')],
            selected: count,
            onSelected: submitting ? null : (value) => setState(() => _count.text = '$value'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _count,
            enabled: !submitting,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            onChanged: (_) => setState(() {}),
            decoration: formFieldDecoration(context, hint: 'Outro número', helper: 'De 2 a 48 parcelas.'),
            validator: (value) => _parsedCount() == null ? 'Escolha de 2 a 48 parcelas.' : null,
          ),
          formGap,
          const FieldLabel('Descrição'),
          TextFormField(
            controller: _description,
            enabled: !submitting,
            textCapitalization: TextCapitalization.sentences,
            decoration: formFieldDecoration(context, hint: 'Ex.: Geladeira, Notebook'),
            validator: (value) {
              final description = (value ?? '').trim();
              if (description.isEmpty || description.length > 200) {
                return 'Informe uma descrição (até 200 caracteres).';
              }
              return null;
            },
          ),
          formGap,
          const FieldLabel('Categoria'),
          if (state.categories.isEmpty)
            Text('Nenhuma categoria disponível.', style: text.bodyMedium)
          else
            ChoicePills<String>(
              options: [
                for (final category in state.categories)
                  PillOption(category.id, category.name, icon: categoryIcon(category.icon)),
              ],
              selected: _categoryId,
              onSelected: submitting
                  ? null
                  : (id) => setState(() => _categoryId = _categoryId == id ? null : id),
            ),
          formGap,
          const FieldLabel('Data da compra'),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.event),
              title: Text(formatDateBr(_date)),
              subtitle: const Text('Toque para mudar'),
              onTap: submitting ? null : _pickDate,
            ),
          ),
          formGap,
          const InfoBox(
            icon: Icons.info_outline,
            text: 'As parcelas vão para as faturas seguintes, uma por mês, a partir da data da compra.',
          ),
        ],
      ),
    );
  }
}
