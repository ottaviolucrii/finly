import 'package:finly/core/di/injection.dart';
import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/core/utils/date_format.dart';
import 'package:finly/features/audit/domain/audit_filter.dart';
import 'package:finly/features/audit/domain/audit_rules.dart';
import 'package:finly/features/audit/domain/entities/audit_item.dart';
import 'package:finly/features/audit/presentation/audit_texts.dart';
import 'package:finly/features/audit/presentation/cubit/audit_cubit.dart';
import 'package:finly/features/audit/presentation/cubit/audit_state.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The history of changes of one workspace. The cubit is created for
/// [workspace], so it never shows the history of another workspace.
class AuditHistoryPage extends StatelessWidget {
  final WorkspaceEntity workspace;

  const AuditHistoryPage({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuditCubit>()..load(workspace.id),
      child: AuditHistoryView(isBusiness: workspace.type == WorkspaceType.business),
    );
  }
}

/// The screen itself: it uses the [AuditCubit] above it.
class AuditHistoryView extends StatelessWidget {
  final bool isBusiness;

  /// "Now", to say "Hoje" and "Ontem"; tests pass a fixed date.
  final DateTime Function()? clock;

  const AuditHistoryView({super.key, this.isBusiness = false, this.clock});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de alterações'),
        backgroundColor: isBusiness ? AppColors.deepBlue : null,
        foregroundColor: isBusiness ? AppColors.white : null,
      ),
      body: BlocBuilder<AuditCubit, AuditState>(
        builder: (context, state) => Column(
          children: [
            _FilterBar(selected: state.filter),
            if (state.status == AuditStatus.loading && state.items.isNotEmpty)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _body(context, state)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AuditState state) {
    final cubit = context.read<AuditCubit>();

    if (state.items.isEmpty) {
      if (state.status == AuditStatus.failure && state.failure != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(auditFailureMessage(state.failure!), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: cubit.refresh, child: const Text('Tentar de novo')),
              ],
            ),
          ),
        );
      }
      if (state.status == AuditStatus.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nenhuma alteração registrada.', textAlign: TextAlign.center),
        ),
      );
    }

    final now = (clock ?? DateTime.now)();
    final text = Theme.of(context).textTheme;
    final children = <Widget>[];
    String? currentDay;

    for (final item in state.items) {
      final day = dayLabel(item.occurredAt, now);
      if (day != currentDay) {
        currentDay = day;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(day, style: text.titleSmall),
          ),
        );
      }
      children.add(_ItemTile(item: item));
    }

    if (state.hasMore) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: state.loadingMore
              ? const Center(child: CircularProgressIndicator())
              : OutlinedButton(onPressed: cubit.loadMore, child: const Text('Carregar mais')),
        ),
      );
    } else {
      children.add(const SizedBox(height: 24));
    }

    return RefreshIndicator(
      onRefresh: cubit.refresh,
      child: ListView(children: children),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final AuditFilter selected;

  const _FilterBar({required this.selected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          for (final filter in AuditFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(auditFilterLabel(filter)),
                selected: filter == selected,
                onSelected: (_) => context.read<AuditCubit>().setFilter(filter),
              ),
            ),
        ],
      ),
    );
  }
}

IconData _iconOf(AuditKind kind) {
  switch (kind) {
    case AuditKind.created:
      return Icons.add_circle_outline;
    case AuditKind.edited:
      return Icons.edit_outlined;
    case AuditKind.deleted:
      return Icons.delete_outline;
    case AuditKind.trashed:
      return Icons.delete_outline;
    case AuditKind.restored:
      return Icons.restore_from_trash_outlined;
  }
}

class _ItemTile extends StatelessWidget {
  final AuditItem item;

  const _ItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subtitle = [auditTimeText(item.occurredAt), if (item.summary.isNotEmpty) item.summary]
        .join(' · ');

    final title = Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis);
    final leading = Icon(_iconOf(item.kind));

    if (item.changes.isEmpty) {
      return ListTile(leading: leading, title: title, subtitle: Text(subtitle));
    }

    return ExpansionTile(
      leading: leading,
      title: title,
      subtitle: Text(subtitle),
      childrenPadding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final change in item.changes)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${change.label}: ', style: text.labelLarge),
                  TextSpan(text: change.before, style: text.bodyMedium),
                  const TextSpan(text: '  →  '),
                  TextSpan(
                    text: change.after,
                    style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
