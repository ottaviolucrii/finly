import 'package:finly/features/reports/data/pdf_report_builder.dart';
import 'package:finly/features/reports/domain/report_pdf_builder.dart';
import 'package:finly/features/reports/domain/usecases/export_report_pdf_use_case.dart';
import 'package:finly/features/reports/presentation/cubit/pdf_export_cubit.dart';
import 'package:get_it/get_it.dart';

/// Registers the PDF of the monthly report. It reads the report with the use
/// case of the reports module, and shares it with the same `FileSharer` as the
/// CSV export.
void registerReportsPdfModule(GetIt sl) {
  sl
    ..registerLazySingleton<ReportPdfBuilder>(() => PdfReportBuilder())
    ..registerLazySingleton(() => ExportReportPdfUseCase(sl(), sl()))
    ..registerFactory(() => PdfExportCubit(exportPdf: sl(), sharer: sl()));
}
