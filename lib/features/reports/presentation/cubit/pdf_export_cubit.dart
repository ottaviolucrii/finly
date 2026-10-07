import 'package:finly/core/error/failure.dart';
import 'package:finly/core/share/file_sharer.dart';
import 'package:finly/features/reports/domain/usecases/export_report_pdf_use_case.dart';
import 'package:finly/features/reports/presentation/cubit/export_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Builds the PDF of the report of a month and opens the share sheet with it.
/// It uses the same state as the CSV export: exporting, done or failure.
class PdfExportCubit extends Cubit<ExportState> {
  final ExportReportPdfUseCase _exportPdf;
  final FileSharer _sharer;

  PdfExportCubit({
    required ExportReportPdfUseCase exportPdf,
    required FileSharer sharer,
  })  : _exportPdf = exportPdf,
        _sharer = sharer,
        super(const ExportState());

  Future<void> export({
    required String workspaceId,
    required String workspaceName,
    required DateTime month,
  }) async {
    if (state.status == ExportStatus.exporting) return;

    emit(const ExportState(status: ExportStatus.exporting));
    final result = await _exportPdf(
      ExportReportPdfParams(
        workspaceId: workspaceId,
        workspaceName: workspaceName,
        month: month,
      ),
    );
    if (isClosed) return;

    await result.fold<Future<void>>(
      (failure) async => emit(
        ExportState(status: ExportStatus.failure, failure: failure),
      ),
      (file) async {
        try {
          await _sharer.shareFile(
            fileName: file.fileName,
            bytes: file.bytes,
            mimeType: 'application/pdf',
          );
          if (!isClosed) emit(const ExportState(status: ExportStatus.done));
        } catch (e) {
          // A platform problem with the share sheet, not a data problem.
          debugPrint('Share failed: $e');
          if (!isClosed) {
            emit(const ExportState(
              status: ExportStatus.failure,
              failure: ServerFailure('share_failed'),
            ));
          }
        }
      },
    );
  }
}
