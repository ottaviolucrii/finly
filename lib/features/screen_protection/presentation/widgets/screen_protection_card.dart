import 'package:finly/core/di/injection.dart';
import 'package:finly/features/screen_protection/presentation/cubit/screen_protection_cubit.dart';
import 'package:finly/features/screen_protection/presentation/cubit/screen_protection_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The "Privacidade" section of the settings screen. It has its own cubit.
class ScreenProtectionCard extends StatelessWidget {
  const ScreenProtectionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ScreenProtectionCubit>()..load(),
      child: const ScreenProtectionSection(),
    );
  }
}

/// The section itself: it uses the [ScreenProtectionCubit] above it. It shows
/// nothing on a phone that cannot block screenshots.
class ScreenProtectionSection extends StatelessWidget {
  const ScreenProtectionSection({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return BlocConsumer<ScreenProtectionCubit, ScreenProtectionState>(
      listenWhen: (previous, current) => current.failed && !previous.failed,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Não foi possível mudar. Tente de novo.')),
          );
      },
      builder: (context, state) {
        if (state.status == ScreenProtectionStatus.unsupported) {
          return const SizedBox.shrink();
        }

        final ready = state.status == ScreenProtectionStatus.ready && !state.saving;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Privacidade', style: text.titleMedium),
            ),
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.visibility_off_outlined),
                title: const Text('Bloquear capturas de tela'),
                subtitle: Text(
                  state.enabled
                      ? 'Prints estão bloqueados e o app aparece em branco na lista de '
                          'apps recentes. Desligue para tirar um print.'
                      : 'Impede prints e esconde o conteúdo na lista de apps recentes.',
                ),
                value: state.enabled,
                onChanged: ready
                    ? (value) => context.read<ScreenProtectionCubit>().setEnabled(value)
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}
