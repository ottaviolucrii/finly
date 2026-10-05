import 'package:finly/core/di/injection.dart';
import 'package:finly/core/money/money.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/budgets/presentation/budget_messages.dart';
import 'package:finly/features/budgets/presentation/cubit/budget_form_cubit.dart';
import 'package:finly/features/budgets/presentation/cubit/budget_form_state.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Sets the limit of a category from [month] on. When [editing] is given the
/// category is fixed and the form starts with its current limit. Pops with
/// `true` when saved.
class BudgetFormPage extends StatelessWidget {
  final String workspaceId;
  final DateTime month;
  final List<CategoryEntity> categories;
  final BudgetProgress? editing;

  const BudgetFormPage({
    super.key,
    required this.workspaceId,
    required this.month,
    required this.categories,
    this.editing,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BudgetFormCubit>(),
      child: _BudgetFormView(
        workspaceId: workspaceId,
        month: month,
        categories: categories,
        editing: editing,
      ),
    );
  }
}

class _BudgetFormView extends StatefulWidget {
  final String workspaceId;
  final DateTime month;
  final List<CategoryEntity> categories;
  final BudgetProgress? editing;

  const _BudgetFormView({
    required this.workspaceId,
    required this.month,
    required this.categories,
    required this.editing,
  });

  @override
  State<_BudgetFormView> createState() => _BudgetFormViewState();
}

class _BudgetFormViewState extends State<_BudgetFormView> {
  static const _currencies = ['BRL', 'USD', 'EUR'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _limit = TextEditingController(
    text: widget.editing?.limit.format(withSymbol: false) ?? '',
  );
  late String? _categoryId = widget.editing?.category.id;
  late String _currency = widget.editing?.currency ?? 'BRL';

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  void _submit() {
    final categoryId = _categoryId;
    if (categoryId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Escolha uma categoria.')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final limit = Money.tryParse(_limit.text, _currency);
    if (limit == null || limit.cents <= 0) return;

    context.read<BudgetFormCubit>().submit(
          workspaceId: widget.workspaceId,
          categoryId: categoryId,
          month: widget.month,
          limitCents: limit.cents,
          currency: _currency,
        );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final editing = widget.editing != null;

    return BlocConsumer<BudgetFormCubit, BudgetFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == BudgetFormStatus.failure && state.failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(budgetFailureMessage(state.failure!))),
            );
        }
        if (state.status == BudgetFormStatus.success) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final submitting = state.status == BudgetFormStatus.submitting;

        return Scaffold(
          appBar: AppBar(
            title: Text(editing ? 'Editar orçamento' : 'Definir orçamento'),
          ),
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
                        Text('Categoria', style: text.labelLarge),
                        const SizedBox(height: 8),
                        if (widget.categories.isEmpty)
                          Text('Nenhuma categoria de despesa.', style: text.bodyMedium)
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final category in widget.categories)
                                ChoiceChip(
                                  avatar: Icon(categoryIcon(category.icon), size: 18),
                                  label: Text(category.name),
                                  selected: _categoryId == category.id,
                                  // The category of an existing budget is fixed.
                                  onSelected: (submitting || editing)
                                      ? null
                                      : (selected) => setState(
                                            () => _categoryId =
                                                selected ? category.id : null,
                                          ),
                                ),
                            ],
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
                                    : (_) => setState(() => _currency = currency),
                              ),
                          ],
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
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'Limite mensal',
                            prefixText: '${Money.symbolFor(_currency)} ',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final limit = Money.tryParse(value ?? '', _currency);
                            return (limit == null || limit.cents <= 0)
                                ? 'Informe um limite maior que zero (ex.: 800,00).'
                                : null;
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vale a partir de ${monthYearLabel(widget.month)} e nos '
                          'meses seguintes, até você definir outro valor. Os meses '
                          'anteriores não mudam.',
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