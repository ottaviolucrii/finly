import 'package:finly/core/di/injection.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/presentation/category_messages.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:finly/features/categories/presentation/cubit/category_form_cubit.dart';
import 'package:finly/features/categories/presentation/cubit/category_form_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Creates a category, or edits [editing]. When editing, the kind is fixed.
/// Pops with `true` when saved.
class CategoryFormPage extends StatelessWidget {
  final String workspaceId;
  final CategoryKind initialKind;
  final CategoryEntity? editing;

  const CategoryFormPage({
    super.key,
    required this.workspaceId,
    required this.initialKind,
    this.editing,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CategoryFormCubit>(),
      child: _CategoryFormView(
        workspaceId: workspaceId,
        initialKind: initialKind,
        editing: editing,
      ),
    );
  }
}

class _CategoryFormView extends StatefulWidget {
  final String workspaceId;
  final CategoryKind initialKind;
  final CategoryEntity? editing;

  const _CategoryFormView({
    required this.workspaceId,
    required this.initialKind,
    required this.editing,
  });

  @override
  State<_CategoryFormView> createState() => _CategoryFormViewState();
}

class _CategoryFormViewState extends State<_CategoryFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.editing?.name ?? '');
  late CategoryKind _kind = widget.editing?.kind ?? widget.initialKind;
  late String _icon = widget.editing?.icon ?? 'category';
  late String _color = widget.editing?.colorHex ?? categoryColorChoices.first;

  bool get _isEditing => widget.editing != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final cubit = context.read<CategoryFormCubit>();
    final editing = widget.editing;

    if (editing != null) {
      cubit.update(
        categoryId: editing.id,
        name: _name.text,
        icon: _icon,
        colorHex: _color,
      );
    } else {
      cubit.create(
        workspaceId: widget.workspaceId,
        name: _name.text,
        kind: _kind,
        icon: _icon,
        colorHex: _color,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final tint = categoryColor(_color);
    final onTint = ThemeData.estimateBrightnessForColor(tint) == Brightness.dark
        ? AppColors.white
        : AppColors.midnight;

    return BlocConsumer<CategoryFormCubit, CategoryFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == CategoryFormStatus.failure && state.failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(categoryFailureMessage(state.failure!))),
            );
        }
        if (state.status == CategoryFormStatus.success) {
          Navigator.of(context).pop(true);
        }
      },
      builder: (context, state) {
        final submitting = state.status == CategoryFormStatus.submitting;

        return Scaffold(
          appBar: AppBar(
            title: Text(_isEditing ? 'Editar categoria' : 'Nova categoria'),
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
                        Center(
                          child: CircleAvatar(
                            radius: 32,
                            backgroundColor: tint,
                            foregroundColor: onTint,
                            child: Icon(categoryIcon(_icon), size: 32),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _name,
                          enabled: !submitting,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Nome',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final name = (value ?? '').trim();
                            if (name.isEmpty || name.length > 60) {
                              return 'Informe um nome (até 60 caracteres).';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        Text('Tipo', style: text.labelLarge),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Despesa'),
                              selected: _kind == CategoryKind.expense,
                              // The kind of an existing category is fixed.
                              onSelected: (submitting || _isEditing)
                                  ? null
                                  : (_) => setState(
                                        () => _kind = CategoryKind.expense,
                                      ),
                            ),
                            ChoiceChip(
                              label: const Text('Receita'),
                              selected: _kind == CategoryKind.income,
                              onSelected: (submitting || _isEditing)
                                  ? null
                                  : (_) => setState(
                                        () => _kind = CategoryKind.income,
                                      ),
                            ),
                          ],
                        ),
                        if (_isEditing)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'O tipo não pode ser alterado: há transações que dependem dele.',
                              style: text.bodySmall,
                            ),
                          ),
                        const SizedBox(height: 20),
                        Text('Ícone', style: text.labelLarge),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final name in categoryIconNames)
                              Semantics(
                                label: name,
                                selected: name == _icon,
                                button: true,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: submitting
                                      ? null
                                      : () => setState(() => _icon = name),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: name == _icon
                                            ? scheme.primary
                                            : scheme.outline.withValues(alpha: 0.4),
                                        width: name == _icon ? 3 : 1,
                                      ),
                                    ),
                                    child: Icon(categoryIcon(name)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text('Cor', style: text.labelLarge),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final hex in categoryColorChoices)
                              Semantics(
                                label: 'Cor $hex',
                                selected: hex == _color,
                                button: true,
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: submitting
                                      ? null
                                      : () => setState(() => _color = hex),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: categoryColor(hex),
                                      border: Border.all(
                                        color: hex == _color
                                            ? scheme.onSurface
                                            : scheme.outline.withValues(alpha: 0.4),
                                        width: hex == _color ? 3 : 1,
                                      ),
                                    ),
                                    child: hex == _color
                                        ? Icon(
                                            Icons.check,
                                            color: ThemeData.estimateBrightnessForColor(
                                                      categoryColor(hex),
                                                    ) ==
                                                    Brightness.dark
                                                ? AppColors.white
                                                : AppColors.midnight,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        FilledButton(
                          onPressed: submitting ? null : _submit,
                          child: submitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(_isEditing ? 'Salvar alterações' : 'Criar categoria'),
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