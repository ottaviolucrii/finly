import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/features/reports/domain/entities/monthly_report.dart';
import 'package:finly/features/reports/domain/report_pdf_builder.dart';
import 'package:finly/features/reports/domain/usecases/export_report_pdf_use_case.dart';
import 'package:finly/features/reports/domain/usecases/get_monthly_report_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetReport extends Mock implements GetMonthlyReportUseCase {}

class MockBuilder extends Mock implements ReportPdfBuilder {}

void main() {
  late MockGetReport getReport;
  late MockBuilder builder;
  late ExportReportPdfUseCase useCase;

  final now = DateTime(2026, 10, 7, 9, 5);
  final month = DateTime(2026, 10);

  const currency = CurrencyReport(
    currency: 'BRL',
    incomeCents: 500000,
    expenseCents: 300000,
    previousIncomeCents: 400000,
    previousExpenseCents: 350000,
    categories: [],
    topExpenses: [],
  );
  final report = MonthlyReport(month: month, byCurrency: const [currency]);

  setUpAll(() {
    registerFallbackValue(GetMonthlyReportParams(workspaceId: 'w1', month: month));
    registerFallbackValue(report);
    registerFallbackValue(now);
  });

  setUp(() {
    getReport = MockGetReport();
    builder = MockBuilder();
    useCase = ExportReportPdfUseCase(getReport, builder, clock: () => now);
  });

  ExportReportPdfParams params({String id = 'w1', DateTime? on}) {
    return ExportReportPdfParams(
      workspaceId: id,
      workspaceName: ' Pessoal ',
      month: on ?? DateTime(2026, 10, 17),
    );
  }

  void stubReport(Either<Failure, MonthlyReport> result) {
    when(() => getReport(any())).thenAnswer((_) async => result);
  }

  void stubBuilder() {
    when(() => builder.build(
          report: any(named: 'report'),
          workspaceName: any(named: 'workspaceName'),
          generatedAt: any(named: 'generatedAt'),
        )).thenAnswer((_) async => [37, 80, 68, 70]);
  }

  test('rejects an empty workspace id', () async {
    final result = await useCase(params(id: ' '));

    expect(result, const Left<Failure, PdfExportResult>(ValidationFailure('invalid_workspace')));
    verifyNever(() => getReport(any()));
  });

  test('reads the report of the first day of the month', () async {
    stubReport(Right(report));
    stubBuilder();

    await useCase(params());

    verify(
      () => getReport(GetMonthlyReportParams(workspaceId: 'w1', month: DateTime(2026, 10))),
    ).called(1);
  });

  test('draws the report and names the file after the month', () async {
    stubReport(Right(report));
    stubBuilder();

    final result = await useCase(params());

    result.fold(
      (failure) => fail('expected a file, got $failure'),
      (file) {
        expect(file.fileName, 'finly-relatorio-2026-10.pdf');
        expect(file.bytes, [37, 80, 68, 70]);
      },
    );
  });

  test('gives the builder the report, the trimmed name and the time', () async {
    stubReport(Right(report));
    stubBuilder();

    await useCase(params());

    verify(() => builder.build(
          report: report,
          workspaceName: 'Pessoal',
          generatedAt: now,
        )).called(1);
  });

  test('a month with nothing is not exported', () async {
    stubReport(Right(MonthlyReport(month: month, byCurrency: const [])));

    final result = await useCase(params());

    expect(result, const Left<Failure, PdfExportResult>(ValidationFailure('nothing_to_export')));
    verifyNever(() => builder.build(
          report: any(named: 'report'),
          workspaceName: any(named: 'workspaceName'),
          generatedAt: any(named: 'generatedAt'),
        ));
  });

  test('passes a failure of the report through unchanged', () async {
    stubReport(const Left(NetworkFailure('network_error')));

    final result = await useCase(params());

    expect(result, const Left<Failure, PdfExportResult>(NetworkFailure('network_error')));
  });

  test('a problem drawing the document becomes pdf_failed', () async {
    stubReport(Right(report));
    when(() => builder.build(
          report: any(named: 'report'),
          workspaceName: any(named: 'workspaceName'),
          generatedAt: any(named: 'generatedAt'),
        )).thenThrow(StateError('no font'));

    final result = await useCase(params());

    expect(result, const Left<Failure, PdfExportResult>(ServerFailure('pdf_failed')));
  });
}
