import 'package:finly/core/di/injection.dart';
import 'package:finly/core/utils/byte_format.dart';
import 'package:finly/features/offline_cache/presentation/cubit/offline_cache_cubit.dart';
import 'package:finly/features/offline_cache/presentation/cubit/offline_cache_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The "Uso sem internet" section of the settings screen. It has its own cubit.
class OfflineCacheCard extends StatelessWidget {
  const OfflineCacheCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OfflineCacheCubit>()..load(),
      child: const OfflineCacheSection(),
    );
  }
}

/// The section itself: it uses the [OfflineCacheCubit] above it.
class OfflineCacheSection extends StatelessWidget {
  const OfflineCacheSection({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return BlocConsumer<OfflineCacheCubit, OfflineCacheState>(
      listenWhen: (previous, current) =>
          current.erased != previous.erased || (current.failed && !previous.failed),
      listener: (context, state) {
        final message = state.failed ? 'Não foi possível mudar. Tente de novo.' : 'Dados guardados apagados.';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      builder: (context, state) {
        final cubit = context.read<OfflineCacheCubit>();
        final canChange = state.loaded && !state.busy;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Uso sem internet', style: text.titleMedium),
            ),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.cloud_off_outlined),
                    title: const Text('Guardar dados para usar sem internet'),
                    subtitle: const Text(
                      'Mostra os últimos dados quando a internet cai. Ficam só neste '
                      'celular, sem criptografia. Ao desligar, o que foi guardado é apagado.',
                    ),
                    value: state.enabled,
                    onChanged: canChange ? cubit.setEnabled : null,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Apagar dados guardados'),
                    subtitle: Text(
                      state.sizeBytes == 0 ? 'Nada guardado' : 'Usando ${formatBytes(state.sizeBytes)}',
                    ),
                    onTap: canChange && state.sizeBytes > 0 ? cubit.erase : null,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
