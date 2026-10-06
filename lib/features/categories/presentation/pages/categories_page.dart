import 'package:finly/core/di/injection.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/categories/domain/entities/category_entity.dart';
import 'package:finly/features/categories/domain/entities/category_kind.dart';
import 'package:finly/features/categories/presentation/category_messages.dart';
import 'package:finly/features/categories/presentation/category_style.dart';
import 'package:finly/features/categories/presentation/cubit/categories_cubit.dart';
import 'package:finly/features/categories/presentation/cubit/categories_state.dart';
import 'package:finly/features/categories/presentation/pages/category_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Categories of one workspace. The cubit is created for [workspace], so it
/// never shows categories of another workspace.
class CategoriesPage extends StatelessWidget {
  final WorkspaceEntity workspace;

  const CategoriesPage({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CategoriesCubit>()..load(workspace.id),
      child: _CategoriesView(workspace: workspace),
    );
  }
}

class _CategoriesView extends StatefulWidget {
  final WorkspaceEntity workspace;

  const _CategoriesView({required this.workspace});

  @override
  State<_CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends State<_CategoriesView> {
  CategoryKind _kind = CategoryKind.expense;

  Future<void> _openForm({CategoryEntity? editing}) async {
    final cubit = context.read<CategoriesCubit>();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CategoryFormPage(
          workspaceId: widget.workspace.id,
          initialKind: _kind,
          editing: editing,
        ),
      ),
    );
    if (saved == true) await cubit.reload();
  }

  Future<void> _confirmArchive(CategoryEntity category) async {
    final cubit = context.read<CategoriesCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Arquivar categoria?'),
        content: Text(
          '"${category.name}" some dos formulários e dos orçamentos. As '
          'transações antigas continuam com ela e passam a mostrar '
          '"Categoria arquivada". Você pode restaurá-la quando quiser.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Arquivar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.setArchived(category, archived: true);
  }

  @override
  Widget build(BuildContext context) {
    final isBusiness = widget.workspace.type == WorkspaceType.business;

    return BlocConsumer<CategoriesCubit, CategoriesState>(
      listenWhen: (previous, current) =>
          current.actionFailure != null &&
          previous.actionFailure != current.actionFailure,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(categoryFailureMessage(state.actionFailure!))),
          );
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Categorias'),
            backgroundColor: isBusiness ? AppColors.deepBlue : null,
            foregroundColor: isBusiness ? AppColors.white : null,
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openForm,
            icon: const Icon(Icons.add),
            label: const Text('Nova categoria'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SegmentedButton<CategoryKind>(
                  segments: const [
                    ButtonSegment(
                      value: CategoryKind.expense,
                      label: Text('Despesas'),
                      icon: Icon(Icons.arrow_upward),
                    ),
                    ButtonSegment(
                      value: CategoryKind.income,
                      label: Text('Receitas'),
                      icon: Icon(Icons.arrow_downward),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (selection) =>
                      setState(() => _kind = selection.first),
                ),
              ),
              Expanded(child: _body(state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(CategoriesState state) {
    if (state.status == CategoriesStatus.failure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                categoryFailureMessage(state.failure!),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.read<CategoriesCubit>().reload(),
                child: const Text('Tentar de novo'),
              ),
            ],
          ),
        ),
      );
    }
    if (state.status != CategoriesStatus.loaded && state.categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final ofKind = state.categories.where((c) => c.kind == _kind).toList();
    final active = ofKind.where((c) => !c.isArchived).toList();
    final archived = ofKind.where((c) => c.isArchived).toList();
    final text = Theme.of(context).textTheme;
    final cubit = context.read<CategoriesCubit>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        if (active.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nenhuma categoria ${_kind == CategoryKind.expense ? 'de despesa' : 'de receita'} ativa.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        for (final category in active)
          _CategoryTile(
            category: category,
            onTap: () => _openForm(editing: category),
            trailing: PopupMenuButton<String>(
              tooltip: 'Mais opções',
              onSelected: (value) {
                if (value == 'edit') {
                  _openForm(editing: category);
                } else {
                  _confirmArchive(category);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'archive', child: Text('Arquivar')),
              ],
            ),
          ),
        if (archived.isNotEmpty)
          Card(
            child: ExpansionTile(
              title: Text('Arquivadas (${archived.length})'),
              children: [
                for (final category in archived)
                  _CategoryTile(
                    category: category,
                    dimmed: true,
                    trailing: TextButton(
                      onPressed: () => cubit.setArchived(category, archived: false),
                      child: const Text('Restaurar'),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryEntity category;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool dimmed;

  const _CategoryTile({
    required this.category,
    required this.trailing,
    this.onTap,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = categoryColor(category.colorHex);
    final foreground =
        ThemeData.estimateBrightnessForColor(tint) == Brightness.dark
            ? AppColors.white
            : AppColors.midnight;

    final tile = ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: tint,
        foregroundColor: foreground,
        child: Icon(categoryIcon(category.icon)),
      ),
      title: Text(category.name, overflow: TextOverflow.ellipsis),
      trailing: trailing,
    );

    return dimmed ? Opacity(opacity: 0.6, child: tile) : Card(child: tile);
  }
}