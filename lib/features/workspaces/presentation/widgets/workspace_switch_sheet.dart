import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/workspaces/presentation/workspace_style.dart';
import 'package:flutter/material.dart';

/// Confirmation sheet shown before changing workspace. Switching is never a
/// single tap (SRS FR-W04), so a misclick cannot move the user to the wrong
/// workspace.
class WorkspaceSwitchSheet extends StatelessWidget {
  final WorkspaceEntity from;
  final WorkspaceEntity to;
  final VoidCallback onConfirm;

  const WorkspaceSwitchSheet({
    super.key,
    required this.from,
    required this.to,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Trocar de workspace',
              style: text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _WorkspaceRow(label: 'Você está em', workspace: from),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(Icons.arrow_downward),
            ),
            _WorkspaceRow(label: 'Mudar para', workspace: to),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onConfirm,
              child: Text('Mudar para ${to.name}'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceRow extends StatelessWidget {
  final String label;
  final WorkspaceEntity workspace;

  const _WorkspaceRow({required this.label, required this.workspace});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: workspaceAccent(workspace.type),
          foregroundColor: AppColors.white,
          child: Icon(workspaceIcon(workspace.type)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.bodySmall),
              Text(
                workspace.name,
                style: text.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
              Text(workspaceTypeLabel(workspace.type), style: text.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}