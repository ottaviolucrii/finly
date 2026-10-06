import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/share/file_sharer.dart';
import 'package:finly/core/utils/windows_1252.dart';
import 'package:finly/features/reports/domain/usecases/export_month_use_case.dart';
import 'package:finly/features/reports/presentation/cubit/export_cubit.dart';
import 'package:finly/features/reports/presentation/cubit/export_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockExportMonth extends Mock implements ExportMonthUseCase {}

class MockSharer extends Mock implements FileSharer {}

void main() {
  late MockExportMonth exportMonth;
  late MockSharer sharer;

  final params = ExportMonthParams(workspaceId: 'w1', month: DateTime(2026, 10));
  const file = ExportResult(
    fileName: 'finly-transacoes-2026-10.csv',
    content: 'Saída;ação',
    rowCount: 3,
    truncated: false,
  );

  setUpAll(() {
    registerFallbackValue(params);
    registerFallbackValue(<int>[]);
  });

  setUp(() {
    exportMonth = MockExportMonth();
    sharer = MockSharer();
  });

  void stubShare() {
    when(() => sharer.shareFile(
          fileName: any(named: 'fileName'),
          bytes: any(named: 'bytes'),
          mimeType: any(named: 'mimeType'),
        )).thenAnswer((_) async {});
  }

  ExportCubit buildCubit() => ExportCubit(exportMonth: exportMonth, sharer: sharer);

  Future<void> run(ExportCubit cubit) =>
      cubit.export(workspaceId: 'w1', month: DateTime(2026, 10));

  blocTest<ExportCubit, ExportState>(
    'emits exporting then done, and shares the file as Windows-1252 bytes',
    build: () {
      when(() => exportMonth(params))
          .thenAnswer((_) async => const Right<Failure, ExportResult>(file));
      stubShare();
      return buildCubit();
    },
    act: run,
    expect: () => [
      const ExportState(status: ExportStatus.exporting),
      const ExportState(status: ExportStatus.done, rowCount: 3),
    ],
    verify: (_) => verify(() => sharer.shareFile(
          fileName: 'finly-transacoes-2026-10.csv',
          bytes: encodeWindows1252('Saída;ação'),
          mimeType: 'text/csv',
        )).called(1),
  );

  blocTest<ExportCubit, ExportState>(
    'a partial file is flagged as truncated',
    build: () {
      when(() => exportMonth(params)).thenAnswer(
        (_) async => const Right<Failure, ExportResult>(
          ExportResult(
            fileName: 'x.csv',
            content: 'c',
            rowCount: 10000,
            truncated: true,
          ),
        ),
      );
      stubShare();
      return buildCubit();
    },
    act: run,
    expect: () => [
      const ExportState(status: ExportStatus.exporting),
      const ExportState(status: ExportStatus.done, rowCount: 10000, truncated: true),
    ],
  );

  blocTest<ExportCubit, ExportState>(
    'a failure building the file is reported and nothing is shared',
    build: () {
      when(() => exportMonth(params)).thenAnswer(
        (_) async => const Left<Failure, ExportResult>(
          ValidationFailure('nothing_to_export'),
        ),
      );
      return buildCubit();
    },
    act: run,
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

  blocTest<ExportCubit, ExportState>(
    'a problem opening the share sheet becomes a failure',
    build: () {
      when(() => exportMonth(params))
          .thenAnswer((_) async => const Right<Failure, ExportResult>(file));
      when(() => sharer.shareFile(
            fileName: any(named: 'fileName'),
            bytes: any(named: 'bytes'),
            mimeType: any(named: 'mimeType'),
          )).thenThrow(StateError('no share sheet'));
      return buildCubit();
    },
    act: run,
    expect: () => [
      const ExportState(status: ExportStatus.exporting),
      const ExportState(
        status: ExportStatus.failure,
        failure: ServerFailure('share_failed'),
      ),
    ],
  );
}