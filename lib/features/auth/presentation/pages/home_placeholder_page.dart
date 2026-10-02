import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/auth/presentation/auth_messages.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/bloc/auth_event.dart';
import 'package:finly/features/auth/presentation/bloc/auth_state.dart';
import 'package:finly/features/workspaces/presentation/pages/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Temporary home after sign-in. Replaced by the dashboard (Phase 4).
class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({super.key});

  static String _typeLabel(WorkspaceType type) =>
      type == WorkspaceType.personal ? 'Pessoal (CPF)' : 'Empresa (CNPJ)';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == AuthStatus.failure,
      listener: (context, state) {
        final failure = state.failure;
        if (failure != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(authFailureMessage(failure))),
            );
        }
      },
      builder: (context, state) {
        final user = state.user;
        if (user == null) return const SizedBox.shrink();
        final firstName = user.fullName.trim().split(' ').first;
        final missing = user.missingWorkspaceType;

        return Scaffold(
          appBar: AppBar(title: const Text('Finly')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Olá, $firstName', style: text.headlineMedium),
                  const SizedBox(height: 4),
                  Text(user.email, style: text.bodyMedium),
                  const SizedBox(height: 24),
                  Text('Seus workspaces', style: text.titleMedium),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final workspace in user.workspaces)
                          Card(
                            child: ListTile(
                              leading: Icon(
                                workspace.type == WorkspaceType.personal
                                    ? Icons.person_outline
                                    : Icons.business_center_outlined,
                              ),
                              title: Text(workspace.name),
                              subtitle: Text(
                                workspace.id == user.activeWorkspaceId
                                    ? '${_typeLabel(workspace.type)} · ativo'
                                    : _typeLabel(workspace.type),
                              ),
                              trailing: workspace.id == user.activeWorkspaceId
                                  ? const Icon(Icons.check_circle)
                                  : null,
                            ),
                          ),
                        if (missing != null) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add),
                            label: Text(
                              missing == WorkspaceType.business
                                  ? 'Adicionar workspace da empresa (CNPJ)'
                                  : 'Adicionar workspace pessoal (CPF)',
                            ),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    OnboardingPage(addingType: missing),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: state.isLoading
                        ? null
                        : () => context
                            .read<AuthBloc>()
                            .add(const SignOutRequested()),
                    child: const Text('Sair'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}