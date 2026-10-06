import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/accounts/domain/entities/account_entity.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:finly/features/transactions/domain/entities/transaction_entity.dart';
import 'package:finly/features/transactions/domain/entities/transaction_status.dart';
import 'package:finly/features/transactions/domain/entities/transaction_type.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_edit_cubit.dart';
import 'package:finly/features/transactions/presentation/cubit/transaction_edit_state.dart';
import 'package:finly/features/transactions/presentation/transaction_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Edits an income or an expense. The type and the account are shown but
/// never change. Pops with `true` when the transaction was saved.
class TransactionEditPage extends StatelessWidget {
  final TransactionEntity transaction;
  final AccountEntity? account;
  final List<CategoryEntity> categories;

  const TransactionEditPage({
    super.key,
    required this.transaction,
    required this.account,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TransactionEditCubit>(),
      child: _TransactionEditView(
        transaction: transaction,
        account: account,
        categories: categories,
      ),
    );
  }
}

class _TransactionEditView extends StatefulWidget {
  final TransactionEntity transaction;
  final AccountEntity? account;
  final List<CategoryEntity> categories;

  const _TransactionEditView({
    required this.transaction,
    required this.account,
    required this.categories,
  });

  @override
  State<_TransactionEditView> createState() => _TransactionEditViewState();
}

class _TransactionEditViewState extends State<_TransactionEditView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount = TextEditingController(
    text: widget.transaction.amount.format(withSymbol: false),
  );
  late final TextEditingController _description =
      TextEditingController(text: widget.transaction.description);
  late String? _categoryId = widget.transaction.categoryId;
  late DateTime _date = widget.transaction.occurredAt;
  late bool _pending = widget.transaction.isPending;

  String get _currency => widget.transaction.currency;

  List<CategoryEntity> get _categoryOptions {
    final kind = widget.transaction.type == TransactionType.income
        ? CategoryKind.income
        : CategoryKind.expense;
    return widget.categories.where((c) => c.kind == kind).toList();
  }

  /// A day that did not change keeps the original time. Another day is
  /// recorded at the current time (today) or at noon.
  DateTime get _occurredAt {
    final original = widget.transaction.occurredAt;
    final sameDay = _date.year == original.year &&
        _date.month == original.month &&
        _date.day == original.day;
    if (sameDay) return original;

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
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = Money.tryParse(_amount.text, _currency);
    if (amount == null || amount.cents <= 0) return;

    context.read<TransactionEditCubit>().submit(
          transactionId: widget.transaction.id,
          categoryId: _categoryId,
          amountCents: amount.cents,
          description: _description.text,
          occurredAt: _occurredAt,
          status: _pending ? TransactionStatus.pending : TransactionStatus.posted,
        );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isIncome = widget.transaction.type == TransactionType.income;
    final options = _categoryOptions;

    return BlocConsumer<TransactionEditCubit, TransactionEditState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == TransactionEditStatus.failure &&
            state.failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(transactionFailureMessage(state.failure!))),
            );
        }
        if (state.status == TransactionEditStatus.success) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final submitting = state.status == TransactionEditStatus.submitting;

        return Scaffold(
          appBar: AppBar(title: const Text('Editar transação')),
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
                          '${isIncome ? 'Entrada' : 'Saída'} · '
                          '${widget.account?.name ?? 'Conta'} ($_currency)',
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'O tipo e a conta não podem ser alterados.',
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
                            labelText: 'Valor',
                            prefixText: '${Money.symbolFor(_currency)} ',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final amount = Money.tryParse(value ?? '', _currency);
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