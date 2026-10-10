import 'package:finly/features/appearance/presentation/widgets/appearance_settings_card.dart';
import 'package:finly/features/screen_protection/presentation/widgets/screen_protection_card.dart';
import 'package:finly/features/offline_cache/presentation/widgets/offline_cache_card.dart';
import 'package:finly/features/auth/domain/entities/user_entity.dart';
import 'package:finly/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:finly/features/auth/presentation/bloc/auth_event.dart';
import 'package:finly/features/lock/domain/entities/lock_settings.dart';
import 'package:finly/features/lock/presentation/cubit/app_lock_cubit.dart';
import 'package:finly/features/lock/presentation/cubit/app_lock_state.dart';
import 'package:finly/features/lock/presentation/lock_texts.dart';
import 'package:finly/features/data_export/presentation/widgets/data_export_card.dart';
import 'package:finly/features/reminders/presentation/widgets/notifications_settings_card.dart';
import 'package:finly/features/settings/presentation/pages/change_password_page.dart';
import 'package:finly/features/settings/presentation/pages/delete_account_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Account settings: who is signed in, the app lock, security, and deleting
/// the account.
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

  Future<void> _pickProtection(BuildContext context, SwitchProtection current) async {
    final cubit = context.read<AppLockCubit>();
    final picked = await showDialog<SwitchProtection>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Ao trocar de workspace'),
        children: [
          for (final level in SwitchProtection.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(level),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(level == current ? Icons.check : null, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(switchProtectionLabel(level)),
                        Text(
                          switchProtectionDescription(level),
                          style: Theme.of(dialogContext).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked != null) await cubit.setSwitchProtection(picked);
  }
  Future<void> _pickTimeout(BuildContext context, int current) async {
    final cubit = context.read<AppLockCubit>();
    final picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Bloquear o app'),
        children: [
          for (final seconds in lockTimeoutOptions)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(seconds),
              child: Row(
                children: [
                  Icon(
                    seconds == current ? Icons.check : null,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(lockTimeoutLabel(seconds)),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked != null && picked != current) await cubit.setTimeout(picked);
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
              child: Text('Bloqueio do app', style: text.titleMedium),
            ),
            BlocConsumer<AppLockCubit, AppLockState>(
              listenWhen: (previous, current) =>
                  previous.error != current.error &&
                  lockSettingsError(current.error) != null,
              listener: (context, state) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(content: Text(lockSettingsError(state.error)!)),
                  );
              },
              builder: (context, lock) {
                final cubit = context.read<AppLockCubit>();

                return Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.timer_outlined),
                        title: const Text('Bloquear o app'),
                        subtitle: Text(lockTimeoutLabel(lock.settings.timeoutSeconds)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _pickTimeout(context, lock.settings.timeoutSeconds),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.fingerprint),
                        title: const Text('Desbloquear com biometria'),
                        subtitle: Text(
                          lock.deviceSupported
                              ? 'Digital ou reconhecimento facial. O PIN do '
                                  'aparelho também funciona.'
                              : 'Este aparelho não tem biometria nem bloqueio '
                                  'de tela configurado.',
                        ),
                        value: lock.settings.biometricEnabled,
                        onChanged: (lock.deviceSupported || lock.settings.biometricEnabled)
                            ? cubit.setBiometric
                            : null,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: const Text('Bloquear agora'),
                        onTap: cubit.lockNow,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.swap_horiz),
                        title: const Text('Prote\u00e7\u00e3o ao trocar de workspace'),
                        subtitle: Text(
                          switchProtectionLabel(lock.settings.switchProtection),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _pickProtection(
                          context,
                          lock.settings.switchProtection,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const AppearanceSettingsCard(),
            const SizedBox(height: 16),
            const ScreenProtectionCard(),
            const SizedBox(height: 16),
            const OfflineCacheCard(),
            const SizedBox(height: 16),
            const NotificationsSettingsCard(),
            const SizedBox(height: 16),
            const DataExportCard(),
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