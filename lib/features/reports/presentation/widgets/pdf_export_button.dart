import 'package:finly/core/di/injection.dart';
import 'package:finly/features/auth/domain/entities/workspace_entity.dart';
import 'package:finly/features/reports/presentation/cubit/export_state.dart';
import 'package:finly/features/reports/presentation/cubit/pdf_export_cubit.dart';
import 'package:finly/features/reports/presentation/cubit/reports_cubit.dart';
import 'package:finly/features/reports/presentation/pdf_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The "PDF" button of the report screen. It has its own cubit, and reads the
/// month on screen from the [ReportsCubit] above it.
class PdfExportButton extends StatelessWidget {
  final WorkspaceEntity workspace;

  const PdfExportButton({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PdfExportCubit>(),
      child: BlocConsumer<PdfExportCubit, ExportState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == ExportStatus.failure && state.failure != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(pdfFailureMessage(state.failure!))),
              );
          }
        },
        builder: (context, state) {
          final busy = state.status == ExportStatus.exporting;

          return IconButton(
            tooltip: 'Exportar o relatório em PDF',
            icon: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: busy
                ? null
                : () => context.read<PdfExportCubit>().export(
                      workspaceId: workspace.id,
                      workspaceName: workspace.name,
                      month: context.read<ReportsCubit>().state.month,
                    ),
          );
        },
      ),
    );
  }
}
