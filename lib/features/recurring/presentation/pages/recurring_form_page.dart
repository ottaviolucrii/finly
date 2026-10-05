import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:finly/features/recurring/domain/entities/recurrence_frequency.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_form_cubit.dart';
import 'package:finly/features/recurring/presentation/cubit/recurring_form_state.dart';
import 'package:finly/features/recurring/presentation/recurring_messages.dart';
import 'package:finly/features/recurring/presentation/recurring_style.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Creates a recurring bill or income. [accounts] must not be empty. Pops with
/// `true` when it was created.
class RecurringFormPage extends StatelessWidget {
  final String workspaceId;
  final List<AccountEntity> accounts;
  final List<CategoryEntity> categories;

  const RecurringFormPage({
    super.key,
    required this.workspaceId,
    required this.accounts,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<RecurringFormCubit>(),
      child: _RecurringFormView(
        workspaceId: workspaceId,
        accounts: accounts,
        categories: categories,
      ),
    );
  }
}

class _RecurringFormView extends StatefulWidget {
  final String workspaceId;
  final List<AccountEntity> accounts;
  final List<CategoryEntity> categories;

  const _RecurringFormView({
    required this.workspaceId,
    required this.accounts,
    required this.categories,
  });

  @override
  State<_RecurringFormView> createState() => _RecurringFormViewState();
}

class _RecurringFormViewState extends State<_RecurringFormView> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _interval = TextEditingController(text: '1');

  TransactionType _type = TransactionType.expense;
  late String _accountId = widget.accounts.first.id;
  String? _categoryId;
  RecurrenceFrequency _frequency = RecurrenceFrequency.monthly;
  DateTime _start = _today();
  DateTime? _end;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  AccountEntity get _account =>
      widget.accounts.firstWhere((account) => account.id == _accountId);

  List<CategoryEntity> get _categoryOptions {
    final kind = _type == TransactionType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    return widget.categories.where((c) => c.kind == kind).toList();
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _start = picked;
      // An end date before the new start would make no sense.
      final end = _end;
      if (end != null && end.isBefore(picked)) _end = null;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end ?? _start,
      firstDate: _start,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _end = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = Money.tryParse(_amount.text, _account.currency);
    final interval = int.tryParse(_interval.text.trim());
    if (amount == null || amount.cents <= 0 || interval == null) return;

    context.read<RecurringFormCubit>().submit(
          workspaceId: widget.workspaceId,
          accountId: _accountId,
          categoryId: _categoryId,
          type: _type,
          amountCents: amount.cents,
          currency: _account.currency,
          description: _description.text,
          frequency: _frequency,
          intervalCount: interval,
          startDate: _start,
          endDate: _end,
        );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return BlocConsumer<RecurringFormCubit, RecurringFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == RecurringFormStatus.failure &&
            state.failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(recurringFailureMessage(state.failure!))),
            );
        }
        if (state.status == RecurringFormStatus.success) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final submitting = state.status == RecurringFormStatus.submitting;
        final options = _categoryOptions;

        return Scaffold(
          appBar: AppBar(title: const Text('Nova recorrência')),
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
                        SegmentedButton<TransactionType>(
                          segments: const [
                            ButtonSegment(
                              value: TransactionType.expense,
                              label: Text('Saída'),
                              icon: Icon(Icons.arrow_upward),
                            ),
                            ButtonSegment(
                              value: TransactionType.income,
                              label: Text('Entrada'),
                              icon: Icon(Icons.arrow_downward),
                            ),
                          ],
                          selected: {_type},
                          onSelectionChanged: submitting
                              ? null
                              : (selection) => setState(() {
                                    _type = selection.first;
                                    _categoryId = null;
                                  }),
                        ),
                        const SizedBox(height: 20),
                        Text('Conta', style: text.labelLarge),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final account in widget.accounts)
                              ChoiceChip(
                                label: Text('${account.name} (${account.currency})'),
                                selected: _accountId == account.id,
                                onSelected: submitting
                                    ? null
                                    : (_) => setState(() => _accountId = account.id),
                              ),
                          ],
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
                            prefixText: '${Money.symbolFor(_account.currency)} ',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final amount =
                                Money.tryParse(value ?? '', _account.currency);
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
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Descrição',
                            hintText: 'Ex.: Aluguel, Netflix, Salário',
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
                        const SizedBox(height: 20),
                        Text('Repete', style: text.labelLarge),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final frequency in RecurrenceFrequency.values)
                              ChoiceChip(
                                label: Text(frequencyChipLabel(frequency)),
                                selected: _frequency == frequency,
                                onSelected: submitting
                                    ? null
                                    : (_) => setState(() => _frequency = frequency),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _interval,
                          enabled: !submitting,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                          decoration: InputDecoration(
                            labelText: 'A cada',
                            suffixText: frequencyUnit(_frequency),
                            helperText: 'De 1 a 52.',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final interval = int.tryParse((value ?? '').trim());
                            return (interval == null ||
                                    interval < 1 ||
                                    interval > 52)
                                ? 'Informe de 1 a 52.'
                                : null;
                          },
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event),
                          title: const Text('Começa em'),
                          subtitle: Text(formatDateBr(_start)),
                          onTap: submitting ? null : _pickStart,
                        ),
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
                        Text(
                          'Datas passadas não geram lançamentos. Os próximos '
                          'aparecem como pendentes em Transações.',
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
                              : const Text('Salvar'),
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