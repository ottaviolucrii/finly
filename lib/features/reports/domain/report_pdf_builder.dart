import 'package:finly/features/reports/domain/entities/monthly_report.dart';

/// Draws a monthly report as a PDF document. An interface, so the use case does
/// not depend on the PDF package and tests can use a fake.
abstract class ReportPdfBuilder {
  /// The bytes of the PDF. [workspaceName] is shown under the title and
  /// [generatedAt] in the footer of every page.
  Future<List<int>> build({
    required MonthlyReport report,
    required String workspaceName,
    required DateTime generatedAt,
  });
}
