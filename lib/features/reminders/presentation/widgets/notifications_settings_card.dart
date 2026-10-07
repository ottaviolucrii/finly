import 'package:finly/features/reminders/presentation/cubit/reminders_cubit.dart';
import 'package:finly/features/reminders/presentation/cubit/reminders_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The "Notificações" section of the settings screen: the permission, one
/// switch per kind of reminder, and a way to check that they work.
class NotificationsSettingsCard extends StatefulWidget {
  const NotificationsSettingsCard({super.key});

  @override
  State<NotificationsSettingsCard> createState() => _NotificationsSettingsCardState();
}

class _NotificationsSettingsCardState extends State<NotificationsSettingsCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RemindersCubit>().refresh();
    });
  }

  String _countText(RemindersState state) {
    if (state.status == RemindersStatus.syncing) return 'Atualizando...';
    final count = state.scheduledCount;
    return count == 1 ? '1 lembrete agendado' : '$count lembretes agendados';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Notificações', style: text.titleMedium),
        ),
        BlocConsumer<RemindersCubit, RemindersState>(
          listenWhen: (previous, current) =>
              previous.error != current.error &&
              current.error == RemindersError.saveFailed,
          listener: (context, state) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Não foi possível salvar. Tente de novo.')),
              );
          },
          builder: (context, state) {
            final cubit = context.read<RemindersCubit>();
            final ready = state.prefsReady;

            return Card(
              child: Column(
                children: [
                  if (state.permissionGranted == false) ...[
                    ListTile(
                      leading: const Icon(Icons.notifications_off_outlined),
                      title: const Text('Ativar notificações'),
                      subtitle: const Text(
                        'O Android precisa da sua permissão para mostrar os lembretes.',
                      ),
                      trailing: FilledButton.tonal(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                        onPressed: cubit.requestPermission,
                        child: const Text('Ativar'),
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                  SwitchListTile(
                    secondary: const Icon(Icons.receipt_long_outlined),
                    title: const Text('Contas a pagar'),
                    subtitle: const Text(
                      'Um aviso antes do vencimento e outro no dia, às 9h.',
                    ),
                    value: state.prefs.billReminder,
                    onChanged: ready ? cubit.setBillReminder : null,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.credit_card),
                    title: const Text('Fatura do cartão'),
                    subtitle: const Text(
                      'Avisos 3 dias antes e no dia do vencimento, às 9h.',
                    ),
                    value: state.prefs.cardDue,
                    onChanged: ready ? cubit.setCardDue : null,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.sync),
                    title: const Text('Atualizar lembretes'),
                    subtitle: Text(_countText(state)),
                    onTap: () => cubit.schedule(),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Enviar notificação de teste'),
                    subtitle: const Text('Chega em cerca de 10 segundos.'),
                    onTap: cubit.sendTest,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Text(
                      'Os lembretes são do workspace ativo e são atualizados '
                      'quando você usa o app. Em alguns celulares (como Xiaomi) '
                      'é preciso permitir o início automático e deixar a bateria '
                      'sem restrições para o Finly.',
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
