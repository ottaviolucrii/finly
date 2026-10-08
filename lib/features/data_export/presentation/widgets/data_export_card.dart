import 'package:finly/core/di/injection.dart';
import 'package:finly/features/data_export/presentation/cubit/data_export_cubit.dart';
import 'package:finly/features/data_export/presentation/cubit/data_export_state.dart';
import 'package:finly/features/data_export/presentation/data_export_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The "Meus dados" section of the settings screen. It has its own cubit.
class DataExportCard extends StatelessWidget {
  const DataExportCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DataExportCubit>(),
      child: const DataExportSection(),
    );
  }
}

/// The section itself: it uses the [DataExportCubit] above it.
class DataExportSection extends StatelessWidget {
  const DataExportSection({super.key});

  Future<void> _confirmAndExport(BuildContext context) async {
    final cubit = context.read<DataExportCubit>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exportar meus dados?'),
        content: const Text(
          'O arquivo tem todas as suas contas, lançamentos e outros dados, '
          'sem criptografia. Guarde com cuidado e envie só para quem você '
          'confia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Exportar'),
          ),
        ],
      ),
    );

    if (confirmed == true) cubit.export();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Meus dados', style: text.titleMedium),
        ),
        BlocConsumer<DataExportCubit, DataExportState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            String? message;
            if (state.status == DataExportStatus.failure && state.failure != null) {
              message = dataExportFailureMessage(state.failure!);
            } else if (state.status == DataExportStatus.done && state.truncated) {
              message = dataExportTruncatedMessage;
            }
            if (message == null) return;

            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
          },
          builder: (context, state) {
            final busy = state.status == DataExportStatus.exporting;

            return Card(
              child: ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Exportar meus dados'),
                subtitle: const Text(
                  'Um arquivo com tudo o que você cadastrou, em JSON.',
                ),
                trailing: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: busy ? null : () => _confirmAndExport(context),
              ),
            );
          },
        ),
      ],
    );
  }
}
