import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_form_cubit.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_form_state.dart';
import 'package:finly/features/transactions/presentation/transaction_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Creates an income or an expense. [accounts] must not be empty. Pops with
/// `true` when the transaction was created.
class TransactionFormPage extends StatelessWidget {
  final String workspaceId;
  final List<AccountEntity> accounts;
  final List<CategoryEntity> categories;

  const TransactionFormPage({
    super.key,
    required this.workspaceId,
    required this.accounts,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TransactionFormCubit>(),
      child: _TransactionFormView(
        workspaceId: workspaceId,
        accounts: accounts,
        categories: categories,
      ),
    );
  }
}

class _TransactionFormView extends StatefulWidget {
  final String workspaceId;
  final List<AccountEntity> accounts;
  final List<CategoryEntity> categories;

  const _TransactionFormView({
    required this.workspaceId,
    required this.accounts,
    required this.categories,
  });

  @override
  State<_TransactionFormView> createState() => _TransactionFormViewState();
}

class _TransactionFormViewState extends State<_TransactionFormView> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();

  TransactionType _type = TransactionType.expense;
  late String _accountId = widget.accounts.first.id;
  String? _categoryId;
  DateTime _date = DateTime.now();
  bool _pending = false;

  AccountEntity get _account =>
      widget.accounts.firstWhere((account) => account.id == _accountId);

  List<CategoryEntity> get _categoryOptions {
    final kind = _type == TransactionType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    return widget.categories.where((c) => c.kind == kind && !c.isArchived).toList();
  }

  /// Today keeps the current time; another day is recorded at noon.
  DateTime get _occurredAt {
    final now = DateTime.now();
    final isToday =
        _date.year == now.year && _date.month == now.month && _date.day == now.day;
    return isToday ? now : DateTime(_date.year, _date.month, _date.day, 12);
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    final today = DateTime.now();
    final isFuture = DateTime(picked.year, picked.month, picked.day)
        .isAfter(DateTime(today.year, today.month, today.day));
    setState(() {
      _date = picked;
      // A future date has not happened yet.
      if (isFuture) _pending = true;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = Money.tryParse(_amount.text, _account.currency);
    if (amount == null || amount.cents <= 0) return;

    context.read<TransactionFormCubit>().submit(
          workspaceId: widget.workspaceId,
          accountId: _accountId,
          categoryId: _categoryId,
          type: _type,
          status: _pending ? TransactionStatus.pending : TransactionStatus.posted,
          amountCents: amount.cents,
          currency: _account.currency,
          description: _description.text,
          occurredAt: _occurredAt,
        );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return BlocConsumer<TransactionFormCubit, TransactionFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == TransactionFormStatus.failure &&
            state.failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(transactionFailureMessage(state.failure!))),
            );
        }
        if (state.status == TransactionFormStatus.success) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final submitting = state.status == TransactionFormStatus.submitting;
        final options = _categoryOptions;

        return Scaffold(
          appBar: AppBar(title: const Text('Nova transação')),
          body: SafeArea(
            child: Center(
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
                                    : (_) =>
                                        setState(() => _accountId = account.id),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _amount,
                          enabled: !submitting,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                          ],
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Valor',
                            prefixText: '${Money.symbolFor(_account.currency)} ',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final amount =
                                Money.tryParse(value ?? '', _account.currency);
                            return (amount == null || amount.cents <= 0)
                                ? 'Informe um valor maior que zero (ex.: 25,90).'
                                : null;
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
                        TextFormField(
                          controller: _description,
                          enabled: !submitting,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Descrição',
                            hintText: 'Ex.: Mercado, Salário',
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
                          title: const Text('Data'),
                          subtitle: Text(formatDateBr(_date)),
                          onTap: submitting ? null : _pickDate,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Ainda não aconteceu (pendente)'),
                          subtitle: const Text(
                            'Entra no saldo previsto, não no saldo atual.',
                          ),
                          value: _pending,
                          onChanged: submitting
                              ? null
                              : (value) => setState(() => _pending = value),
                        ),
                        const SizedBox(height: 16),
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