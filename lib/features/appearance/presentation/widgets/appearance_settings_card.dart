import 'package:finly/features/appearance/domain/entities/appearance_mode.dart';
import 'package:finly/features/appearance/presentation/appearance_mode_x.dart';
import 'package:finly/features/appearance/presentation/cubit/appearance_cubit.dart';
import 'package:finly/features/appearance/presentation/cubit/appearance_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The "Aparência" section of the settings screen: system, light or dark.
class AppearanceSettingsCard extends StatelessWidget {
  const AppearanceSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Aparência', style: text.titleMedium),
        ),
        BlocConsumer<AppearanceCubit, AppearanceState>(
          listenWhen: (previous, current) =>
              previous.error != current.error &&
              current.error == AppearanceError.saveFailed,
          listener: (context, state) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(content: Text('Não foi possível salvar. Tente de novo.')),
              );
          },
          builder: (context, state) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<AppearanceMode>(
                        showSelectedIcon: false,
                        segments: [
                          for (final mode in AppearanceMode.values)
                            ButtonSegment<AppearanceMode>(
                              value: mode,
                              label: Text(mode.label),
                            ),
                        ],
                        selected: {state.mode},
                        onSelectionChanged: (selection) =>
                            context.read<AppearanceCubit>().setMode(selection.first),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sistema segue o claro ou escuro do celular.',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
