import 'package:finly/core/di/injection.dart';
import 'package:finly/core/utils/cents_input_formatter.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/core/widgets/form_parts.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:finly/features/recurring/domain/entities/recurring_entity.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_edit_cubit.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_edit_state.dart';
import 'package:finly/features/recurring/presentation/recurring_messages.dart';
import 'package:finly/features/recurring/presentation/recurring_style.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Edits what a recurring item generates: description, amount, category and
/// end date. The type, the account and the schedule are shown but never
/// change. Pops with `true` when saved.
class RecurringEditPage extends StatelessWidget {
  final RecurringEntity item;
  final AccountEntity? account;
  final List<CategoryEntity> categories;

  const RecurringEditPage({
    super.key,
    required this.item,
    required this.account,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<RecurringEditCubit>(),
      child: _RecurringEditView(
        item: item,
        account: account,
        categories: categories,
      ),
    );
  }
}

class _RecurringEditView extends StatefulWidget {
  final RecurringEntity item;
  final AccountEntity? account;
  final List<CategoryEntity> categories;

  const _RecurringEditView({
    required this.item,
    required this.account,
    required this.categories,
  });

  @override
  State<_RecurringEditView> createState() => _RecurringEditViewState();
}

class _RecurringEditViewState extends State<_RecurringEditView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount = TextEditingController(
    text: widget.item.amount.format(withSymbol: false),
  );
  late final TextEditingController _description =
      TextEditingController(text: widget.item.description);
  late String? _categoryId = widget.item.categoryId;
  late DateTime? _end = widget.item.endDate;

  String get _currency => widget.item.currency;

  List<CategoryEntity> get _categoryOptions {
    final kind = widget.item.type == TransactionType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    return widget.categories.where((c) => c.kind == kind).toList();
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = widget.item.startDate;
    final initial = _end ?? (today.isBefore(start) ? start : today);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: start,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _end = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = centsFromInput(_amount.text);
    if (amount <= 0) return;

    context.read<RecurringEditCubit>().submit(
          id: widget.item.id,
          categoryId: _categoryId,
          amountCents: amount,
          description: _description.text,
          startDate: widget.item.startDate,
          endDate: _end,
        );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final item = widget.item;
    final options = _categoryOptions;

    return BlocConsumer<RecurringEditCubit, RecurringEditState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == RecurringEditStatus.failure && state.failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(recurringFailureMessage(state.failure!))),
            );
        }
        if (state.status == RecurringEditStatus.success) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final submitting = state.status == RecurringEditStatus.submitting;

        return FormPage(
          title: 'Editar recorrência',
          saveLabel: 'Salvar alterações',
          saving: submitting,
          onSave: _submit,
          form: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoBox(
                  icon: Icons.lock_outline,
                  text: '${item.type.isCredit ? 'Entrada' : 'Saída'} · ${widget.account?.name ?? 'Conta'} '
                      '($_currency) · ${frequencyLabel(item.frequency, item.intervalCount)} · desde '
                      '${formatDateBr(item.startDate)}. O tipo, a conta e a frequência não podem ser '
                      'alterados: para mudá-los, exclua e crie outra.',
                ),
                formGap,
                AmountCard(
                  label: 'Valor de cada lançamento',
                  controller: _amount,
                  currency: _currency,
                  enabled: !submitting,
                  validator: (value) => centsFromInput(value ?? '') <= 0
                      ? 'Informe um valor maior que zero.'
                      : null,
                ),
                formGap,
                const FieldLabel('Descrição'),
                TextFormField(
                  controller: _description,
                  enabled: !submitting,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: formFieldDecoration(context),
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
                if (options.isEmpty)
                  Text('Nenhuma categoria disponível.', style: text.bodyMedium)
                else
                  ChoicePills<String>(
                    options: [
                      for (final category in options)
                        PillOption(category.id, category.name, icon: categoryIcon(category.icon)),
                    ],
                    selected: _categoryId,
                    onSelected: submitting
                        ? null
                        : (id) => setState(() => _categoryId = _categoryId == id ? null : id),
                  ),
                formGap,
                const FieldLabel('Termina em (opcional)'),
                DateCard(
                  icon: Icons.event_busy,
                  value: _end == null ? 'Sem data final' : formatDateBr(_end!),
                  onTap: submitting ? null : _pickEnd,
                  onClear: (_end == null || submitting) ? null : () => setState(() => _end = null),
                  clearTooltip: 'Remover data final',
                ),
                formGap,
                const InfoBox(
                  icon: Icons.info_outline,
                  text: 'As mudanças valem para os lançamentos pendentes de hoje em diante. O que já foi '
                      'confirmado ou está atrasado não muda. Lançamentos pendentes depois da data final '
                      'são removidos.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
