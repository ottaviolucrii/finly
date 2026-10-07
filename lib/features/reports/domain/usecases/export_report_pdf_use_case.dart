import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/reports/domain/entities/monthly_report.dart';
import 'package:finly/features/reports/domain/report_pdf_builder.dart';
import 'package:finly/features/reports/domain/report_pdf_rules.dart';
import 'package:finly/features/reports/domain/usecases/get_monthly_report_use_case.dart';

class ExportReportPdfParams extends Equatable {
  final String workspaceId;

  /// Shown under the title of the PDF.
  final String workspaceName;

  /// Any day of the month of the report.
  final DateTime month;

  const ExportReportPdfParams({
    required this.workspaceId,
    required this.workspaceName,
    required this.month,
  });

  @override
  List<Object?> get props => [workspaceId, workspaceName, month];
}

/// A PDF ready to be shared.
class PdfExportResult extends Equatable {
  final String fileName;
  final List<int> bytes;

  const PdfExportResult({required this.fileName, required this.bytes});

  @override
  List<Object?> get props => [fileName, bytes];
}

/// The monthly report as a PDF file. It reads the same report as the screen,
/// so the PDF always shows what the person just looked at.
class ExportReportPdfUseCase
    implements UseCase<PdfExportResult, ExportReportPdfParams> {
  final GetMonthlyReportUseCase _getReport;
  final ReportPdfBuilder _builder;
  final DateTime Function() _clock;

  /// [clock] gives "now" for the footer; tests pass a fixed date.
  ExportReportPdfUseCase(
    this._getReport,
    this._builder, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  @override
  Future<Either<Failure, PdfExportResult>> call(
    ExportReportPdfParams params,
  ) async {
    if (params.workspaceId.trim().isEmpty) {
      return const Left(ValidationFailure('invalid_workspace'));
    }

    final month = DateTime(params.month.year, params.month.month);
    final result = await _getReport(
      GetMonthlyReportParams(workspaceId: params.workspaceId, month: month),
    );

    Failure? failure;
    MonthlyReport? report;
    result.fold((f) {
      failure = f;
    }, (value) {
      report = value;
    });

    final problem = failure;
    if (problem != null) return Left<Failure, PdfExportResult>(problem);

    final data = report;
    if (data == null || data.isEmpty) {
      return const Left(ValidationFailure('nothing_to_export'));
    }

    try {
      final bytes = await _builder.build(
        report: data,
        workspaceName: params.workspaceName.trim(),
        generatedAt: _clock(),
      );
      return Right<Failure, PdfExportResult>(
        PdfExportResult(fileName: pdfFileName(month), bytes: bytes),
      );
    } catch (_) {
      // A problem drawing the document, not a data problem.
      return const Left(ServerFailure('pdf_failed'));
    }
  }
}
