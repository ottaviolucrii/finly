import 'package:finly/core/di/injection.dart';
import 'package:finly/core/utils/cents_input_formatter.dart';
import 'package:finly/core/widgets/form_parts.dart';
import 'package:finly/core/widgets/form_validation.dart';
import 'package:finly/features/budgets/domain/entities/budget_progress.dart';
import 'package:finly/features/budgets/presentation/budget_messages.dart';
import 'package:finly/features/budgets/presentation/cubit/budget_form_cubit.dart';
import 'package:finly/features/budgets/presentation/cubit/budget_form_state.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:finly/features/transactions/presentation/widgets/statement_band.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Sets the limit of a category from [month] on. When [editing] is given the
/// category is fixed and the form starts with its current limit. Pops with
/// `true` when saved.
class BudgetFormPage extends StatelessWidget {
  final String workspaceId;
  final DateTime month;
  final List<CategoryEntity> categories;
  final BudgetProgress? editing;

  /// The category already chosen (a tap on a category without a budget).
  final String? initialCategoryId;

  const BudgetFormPage({
    super.key,
    required this.workspaceId,
    required this.month,
    required this.categories,
    this.editing,
    this.initialCategoryId,
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
        initialCategoryId: initialCategoryId,
      ),
    );
  }
}

class _BudgetFormView extends StatefulWidget {
  final String workspaceId;
  final DateTime month;
  final List<CategoryEntity> categories;
  final BudgetProgress? editing;
  final String? initialCategoryId;

  const _BudgetFormView({
    required this.workspaceId,
    required this.month,
    required this.categories,
    required this.editing,
    required this.initialCategoryId,
  });

  @override
  State<_BudgetFormView> createState() => _BudgetFormViewState();
}

class _BudgetFormViewState extends State<_BudgetFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _limit = TextEditingController(
    text: widget.editing?.limit.format(withSymbol: false) ?? '',
  );
  late String? _categoryId = widget.editing?.category.id ?? widget.initialCategoryId;
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
    if (!validateOnSave(_formKey)) return;
    final cents = centsFromInput(_limit.text);
    if (cents <= 0) return;

    context.read<BudgetFormCubit>().submit(
          workspaceId: widget.workspaceId,
          categoryId: categoryId,
          month: widget.month,
          limitCents: cents,
          currency: _currency,
        );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final editing = widget.editing;
    final monthName = monthTitle(widget.month).toLowerCase();

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

        return FormPage(
          title: editing != null ? 'Editar orçamento' : 'Novo orçamento',
          saveLabel: 'Salvar orçamento',
          saving: submitting,
          onSave: _submit,
          form: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.disabled,
            onChanged: () => revalidateIfTried(_formKey),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FieldLabel('Categoria'),
                if (widget.categories.isEmpty)
                  Text('Nenhuma categoria de despesa.', style: text.bodyMedium)
                else
                  ChoicePills<String>(
                    options: [
                      // The category of an existing budget is fixed: only it is shown.
                      for (final category in widget.categories)
                        if (editing == null || category.id == editing.category.id)
                          PillOption(category.id, category.name, icon: categoryIcon(category.icon)),
                    ],
                    selected: _categoryId,
                    onSelected: (submitting || editing != null)
                        ? null
                        : (id) => setState(() => _categoryId = id),
                  ),
                formGap,
                AmountCard(
                  label: 'Limite por mês',
                  controller: _limit,
                  currency: _currency,
                  enabled: !submitting,
                  validator: (value) => centsFromInput(value ?? '') <= 0
                      ? 'Informe um limite maior que zero.'
                      : null,
                  footer: editing == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Em $monthName você já gastou ${editing.spent.format()} em ${editing.category.name}.',
                            textAlign: TextAlign.center,
                            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                ),
                formGap,
                const FieldLabel('Moeda'),
                ChoicePills<String>(
                  options: currencyPills,
                  selected: _currency,
                  onSelected: submitting ? null : (currency) => setState(() => _currency = currency),
                ),
                formGap,
                InfoBox(
                  icon: Icons.calendar_today_outlined,
                  text: 'Vale a partir de $monthName e nos meses seguintes, até você definir '
                      'outro valor. Os meses anteriores não mudam.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
