import 'package:finly/core/error/failure.dart';
import 'package:finly/features/reports/presentation/reports_messages.dart';

/// The text for a failure when making the PDF (Portuguese for now; replaced by
/// proper localisation in a later phase). Anything that is not about the PDF
/// itself uses the messages of the reports screen.
String pdfFailureMessage(Failure failure) {
  if (failure.message == 'pdf_failed') {
    return 'Não foi possível gerar o PDF. Tente de novo.';
  }
  if (failure.message == 'nothing_to_export') {
    return 'Não há movimentações neste mês para o relatório.';
  }
  return reportsFailureMessage(failure);
}
