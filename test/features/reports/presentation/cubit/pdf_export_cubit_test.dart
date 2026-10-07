import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/share/file_sharer.dart';
import 'package:finly/features/reports/domain/usecases/export_report_pdf_use_case.dart';
import 'package:finly/features/reports/presentation/cubit/export_state.dart';
import 'package:finly/features/reports/presentation/cubit/pdf_export_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockExportPdf extends Mock implements ExportReportPdfUseCase {}

class MockSharer extends Mock implements FileSharer {}

void main() {
  late MockExportPdf exportPdf;
  late MockSharer sharer;

  final month = DateTime(2026, 10);
  final params = ExportReportPdfParams(
    workspaceId: 'w1',
    workspaceName: 'Pessoal',
    month: month,
  );
  const file = PdfExportResult(fileName: 'finly-relatorio-2026-10.pdf', bytes: [37, 80, 68, 70]);

  setUpAll(() => registerFallbackValue(params));

  setUp(() {
    exportPdf = MockExportPdf();
    sharer = MockSharer();
  });

  void stubShare() {
    when(() => sharer.shareFile(
          fileName: any(named: 'fileName'),
          bytes: any(named: 'bytes'),
          mimeType: any(named: 'mimeType'),
        )).thenAnswer((_) async {});
  }

  PdfExportCubit build() => PdfExportCubit(exportPdf: exportPdf, sharer: sharer);

  blocTest<PdfExportCubit, ExportState>(
    'builds the PDF and opens the share sheet with it',
    build: () {
      when(() => exportPdf(params)).thenAnswer((_) async => const Right<Failure, PdfExportResult>(file));
      stubShare();
      return build();
    },
    act: (cubit) => cubit.export(workspaceId: 'w1', workspaceName: 'Pessoal', month: month),
    expect: () => [
      const ExportState(status: ExportStatus.exporting),
      const ExportState(status: ExportStatus.done),
    ],
    verify: (_) => verify(() => sharer.shareFile(
          fileName: 'finly-relatorio-2026-10.pdf',
          bytes: const [37, 80, 68, 70],
          mimeType: 'application/pdf',
        )).called(1),
  );

  blocTest<PdfExportCubit, ExportState>(
    'a failure of the use case is reported and nothing is shared',
    build: () {
      when(() => exportPdf(params)).thenAnswer(
        (_) async => const Left<Failure, PdfExportResult>(ValidationFailure('nothing_to_export')),
      );
      return build();
    },
    act: (cubit) => cubit.export(workspaceId: 'w1', workspaceName: 'Pessoal', month: month),
    expect: () => [
      const ExportState(status: ExportStatus.exporting),
      const ExportState(
        status: ExportStatus.failure,
        failure: ValidationFailure('nothing_to_export'),
      ),
    ],
    verify: (_) => verifyNever(() => sharer.shareFile(
          fileName: any(named: 'fileName'),
          bytes: any(named: 'bytes'),
          mimeType: any(named: 'mimeType'),
        )),
  );

  blocTest<PdfExportCubit, ExportState>(
    'a problem with the share sheet becomes share_failed',
    build: () {
      when(() => exportPdf(params)).thenAnswer((_) async => const Right<Failure, PdfExportResult>(file));
      when(() => sharer.shareFile(
            fileName: any(named: 'fileName'),
            bytes: any(named: 'bytes'),
            mimeType: any(named: 'mimeType'),
          )).thenThrow(StateError('no share sheet'));
      return build();
    },
    act: (cubit) => cubit.export(workspaceId: 'w1', workspaceName: 'Pessoal', month: month),
    expect: () => [
      const ExportState(status: ExportStatus.exporting),
      const ExportState(
        status: ExportStatus.failure,
        failure: ServerFailure('share_failed'),
      ),
    ],
  );

  test('a second tap while the PDF is being made is ignored', () async {
    final gate = Completer<Either<Failure, PdfExportResult>>();
    when(() => exportPdf(any())).thenAnswer((_) => gate.future);
    stubShare();
    final cubit = build();

    final first = cubit.export(workspaceId: 'w1', workspaceName: 'Pessoal', month: month);
    await cubit.export(workspaceId: 'w1', workspaceName: 'Pessoal', month: month);
    gate.complete(const Right<Failure, PdfExportResult>(file));
    await first;

    verify(() => exportPdf(any())).called(1);
    expect(cubit.state.status, ExportStatus.done);
    await cubit.close();
  });
}
