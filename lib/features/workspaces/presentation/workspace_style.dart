import 'package:finly/core/theme/app_colors.dart';
import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:flutter/material.dart';

/// Visual identity of each workspace type (docs/UI_GUIDE.md, section 4).

String workspaceTypeLabel(WorkspaceType type) =>
    type == WorkspaceType.personal ? 'Pessoal (CPF)' : 'Empresa (CNPJ)';

IconData workspaceIcon(WorkspaceType type) => type == WorkspaceType.personal
    ? Icons.person_outline
    : Icons.business_center_outlined;

/// Personal uses Tech Blue; Business uses Deep Professional Blue.
Color workspaceAccent(WorkspaceType type) =>
    type == WorkspaceType.personal ? AppColors.techBlue : AppColors.deepBlue;