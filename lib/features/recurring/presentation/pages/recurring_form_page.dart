import 'package:finly/core/di/injection.dart';
import 'package:finly/core/utils/cents_input_formatter.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/core/widgets/form_parts.dart';
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
import 'package:finly/features/transactions/presentation/account_choice.dart';
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

  /// The accounts the current kind can use (no cards for money coming in).
  List<AccountEntity> get _accountOptions => accountsForType(_type, widget.accounts);

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
    final amount = centsFromInput(_amount.text);
    final interval = int.tryParse(_interval.text.trim());
    if (amount <= 0 || interval == null) return;

    context.read<RecurringFormCubit>().submit(
          workspaceId: widget.workspaceId,
          accountId: _accountId,
          categoryId: _categoryId,
          type: _type,
          amountCents: amount,
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
    return BlocConsumer<RecurringFormCubit, RecurringFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == RecurringFormStatus.failure && state.failure != null) {
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
        final text = Theme.of(context).textTheme;
        final income = _type == TransactionType.income;
        final options = _categoryOptions;

        return FormPage(
          title: 'Nova recorrência',
          saveLabel: income ? 'Salvar entrada' : 'Salvar saída',
          saving: submitting,
          onSave: _accountOptions.isEmpty ? null : _submit,
          form: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChoicePills<TransactionType>(
                  options: const [
                    PillOption(TransactionType.expense, 'Saída', icon: Icons.north_east),
                    PillOption(TransactionType.income, 'Entrada', icon: Icons.south_west),
                  ],
                  selected: _type,
                  onSelected: submitting
                      ? null
                      : (type) => setState(() {
                            _type = type;
                            _categoryId = null;
                            final options = _accountOptions;
                            if (options.isNotEmpty && !options.any((a) => a.id == _accountId)) {
                              _accountId = options.first.id;
                            }
                          }),
                ),
                formGap,
                AmountCard(
                  label: 'Valor de cada lançamento',
                  controller: _amount,
                  currency: _account.currency,
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
                  decoration: formFieldDecoration(context, hint: 'Ex.: Aluguel, Netflix, Salário'),
                  validator: (value) {
                    final description = (value ?? '').trim();
                    if (description.isEmpty || description.length > 200) {
                      return 'Informe uma descrição (até 200 caracteres).';
                    }
                    return null;
                  },
                ),
                formGap,
                FieldLabel(income ? 'Receber em' : 'Pagar com'),
                if (_accountOptions.isEmpty)
                  Text(noAccountForIncome, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error))
                else
                  ChoicePills<String>(
                    options: [
                      for (final account in _accountOptions)
                        PillOption(account.id, '${account.name} (${account.currency})'),
                    ],
                    selected: _accountId,
                    onSelected: submitting ? null : (id) => setState(() => _accountId = id),
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
                const FieldLabel('Repete'),
                ChoicePills<RecurrenceFrequency>(
                  options: [
                    for (final frequency in RecurrenceFrequency.values)
                      PillOption(frequency, frequencyChipLabel(frequency)),
                  ],
                  selected: _frequency,
                  onSelected: submitting ? null : (frequency) => setState(() => _frequency = frequency),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _interval,
                  enabled: !submitting,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  decoration: formFieldDecoration(context, helper: 'A cada quantos períodos. De 1 a 52.').copyWith(
                    prefixText: 'A cada ',
                    suffixText: frequencyUnit(_frequency),
                  ),
                  validator: (value) {
                    final interval = int.tryParse((value ?? '').trim());
                    return (interval == null || interval < 1 || interval > 52) ? 'Informe de 1 a 52.' : null;
                  },
                ),
                formGap,
                const FieldLabel('Começa em'),
                DateCard(value: formatDateBr(_start), onTap: submitting ? null : _pickStart),
                const SizedBox(height: 12),
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
                  text: 'Datas passadas não geram lançamentos. Os próximos aparecem como pendentes em '
                      'Extrato, prontos para confirmar.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
