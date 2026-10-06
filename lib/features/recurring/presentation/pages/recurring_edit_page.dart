import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/date_format.dart';
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
import 'package:flutter/services.dart';
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
    final amount = Money.tryParse(_amount.text, _currency);
    if (amount == null || amount.cents <= 0) return;

    context.read<RecurringEditCubit>().submit(
          id: widget.item.id,
          categoryId: _categoryId,
          amountCents: amount.cents,
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
        if (state.status == RecurringEditStatus.failure &&
            state.failure != null) {
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

        return Scaffold(
          appBar: AppBar(title: const Text('Editar recorrência')),
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
                        Text(
                          '${item.type.isCredit ? 'Entrada' : 'Saída'} · '
                          '${widget.account?.name ?? 'Conta'} ($_currency)',
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${frequencyLabel(item.frequency, item.intervalCount)} · '
                          'desde ${formatDateBr(item.startDate)}',
                          style: text.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'O tipo, a conta e a frequência não podem ser '
                          'alterados. Para mudar a frequência ou a data '
                          'inicial, exclua e crie outra.',
                          style: text.bodySmall,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _amount,
                          enabled: !submitting,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                          ],
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Valor de cada lançamento',
                            prefixText: '${Money.symbolFor(_currency)} ',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final amount = Money.tryParse(value ?? '', _currency);
                            return (amount == null || amount.cents <= 0)
                                ? 'Informe um valor maior que zero (ex.: 1.200,00).'
                                : null;
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _description,
                          enabled: !submitting,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Descrição',
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
                        const SizedBox(height: 20),
                        Text('Categoria', style: text.labelLarge),
                        const SizedBox(height: 8),
                        if (options.isEmpty)
                          Text('Nenhuma categoria disponível.', style: text.bodyMedium)
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final category in options)
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
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_busy),
                          title: const Text('Termina em (opcional)'),
                          subtitle: Text(
                            _end == null ? 'Sem data final' : formatDateBr(_end!),
                          ),
                          trailing: _end == null
                              ? null
                              : IconButton(
                                  tooltip: 'Remover data final',
                                  icon: const Icon(Icons.close),
                                  onPressed: submitting
                                      ? null
                                      : () => setState(() => _end = null),
                                ),
                          onTap: submitting ? null : _pickEnd,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'As mudanças valem para os lançamentos pendentes de '
                          'hoje em diante. O que já foi confirmado ou está '
                          'atrasado não muda. Lançamentos pendentes depois da '
                          'data final são removidos.',
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