import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/bloc/auth_event.dart';
import 'package:finly/features/settings/presentation/pages/change_password_page.dart';
import 'package:finly/features/settings/presentation/pages/delete_account_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Account settings: who is signed in, security, and deleting the account.
class SettingsPage extends StatelessWidget {
  final UserEntity user;

  const SettingsPage({super.key, required this.user});

  Future<void> _confirmSignOutEverywhere(BuildContext context) async {
    final navigator = Navigator.of(context);
    final bloc = context.read<AuthBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair de todos os dispositivos?'),
        content: const Text(
          'Todas as sessões abertas, inclusive esta, serão encerradas. '
          'Você precisará entrar de novo em cada aparelho.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sair de todos'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Back to the first screen, so no page stays open above the sign-in.
    navigator.popUntil((route) => route.isFirst);
    bloc.add(const SignOutRequested(allDevices: true));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(user.fullName),
                subtitle: Text(user.email),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Segurança', style: text.titleMedium),
            ),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Alterar senha'),
                    subtitle: const Text('Os outros dispositivos serão desconectados.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (_) => const ChangePasswordPage(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.devices_other),
                    title: const Text('Sair de todos os dispositivos'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _confirmSignOutEverywhere(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Privacidade', style: text.titleMedium),
            ),
            Card(
              child: ListTile(
                leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
                title: Text(
                  'Excluir minha conta',
                  style: TextStyle(color: scheme.error),
                ),
                subtitle: const Text('Apaga todos os seus dados, para sempre.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const DeleteAccountPage(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}