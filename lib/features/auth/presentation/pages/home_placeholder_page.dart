import 'package:finly/features/auth/domain/entities/workspace_type.dart';
import 'package:finly/features/auth/presentation/auth_messages.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/bloc/auth_event.dart';
import 'package:finly/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Temporary home after sign-in. Replaced by the dashboard (Phase 4).
class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({super.key});

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
        final workspace = user.activeWorkspace;

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
                  if (workspace != null) ...[
                    Text(workspace.name, style: text.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      workspace.type == WorkspaceType.personal
                          ? 'Workspace pessoal (CPF)'
                          : 'Workspace da empresa (CNPJ)',
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    'Login e workspace funcionando. O próximo passo são as '
                    'contas e as transações.',
                    style: text.bodyLarge,
                  ),
                  const Spacer(),
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