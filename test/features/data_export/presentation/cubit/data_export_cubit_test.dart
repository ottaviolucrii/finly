import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/share/file_sharer.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/data_export/domain/entities/data_export_result.dart';
import 'package:finly/features/data_export/domain/usecases/export_my_data_use_case.dart';
import 'package:finly/features/data_export/presentation/cubit/data_export_cubit.dart';
import 'package:finly/features/data_export/presentation/cubit/data_export_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockExport extends Mock implements ExportMyDataUseCase {}

class MockSharer extends Mock implements FileSharer {}

void main() {
  late MockExport exportMyData;
  late MockSharer sharer;

  const file = DataExportResult(
    fileName: 'finly-meus-dados-2026-10-07.json',
    bytes: [123, 125],
    rowCount: 42,
    truncated: false,
  );

  setUpAll(() => registerFallbackValue(const NoParams()));

  setUp(() {
    exportMyData = MockExport();
    sharer = MockSharer();
  });

  void stubShare() {
    when(() => sharer.shareFile(
          fileName: any(named: 'fileName'),
          bytes: any(named: 'bytes'),
          mimeType: any(named: 'mimeType'),
        )).thenAnswer((_) async {});
  }

  DataExportCubit build() => DataExportCubit(exportMyData: exportMyData, sharer: sharer);

  blocTest<DataExportCubit, DataExportState>(
    'reads the data and opens the share sheet with the JSON file',
    build: () {
      when(() => exportMyData(any())).thenAnswer((_) async => const Right<Failure, DataExportResult>(file));
      stubShare();
      return build();
    },
    act: (cubit) => cubit.export(),
    expect: () => [
      const DataExportState(status: DataExportStatus.exporting),
      const DataExportState(status: DataExportStatus.done, rowCount: 42),
    ],
    verify: (_) => verify(() => sharer.shareFile(
          fileName: 'finly-meus-dados-2026-10-07.json',
          bytes: const [123, 125],
          mimeType: 'application/json',
        )).called(1),
  );

  blocTest<DataExportCubit, DataExportState>(
    'says when the file holds only a part of the data',
    build: () {
      when(() => exportMyData(any())).thenAnswer(
        (_) async => const Right<Failure, DataExportResult>(
          DataExportResult(fileName: 'f.json', bytes: [1], rowCount: 100000, truncated: true),
        ),
      );
      stubShare();
      return build();
    },
    act: (cubit) => cubit.export(),
    expect: () => [
      const DataExportState(status: DataExportStatus.exporting),
      const DataExportState(status: DataExportStatus.done, rowCount: 100000, truncated: true),
    ],
  );

  blocTest<DataExportCubit, DataExportState>(
    'a failure of the use case is reported and nothing is shared',
    build: () {
      when(() => exportMyData(any())).thenAnswer(
        (_) async => const Left<Failure, DataExportResult>(NetworkFailure('network_error')),
      );
      return build();
    },
    act: (cubit) => cubit.export(),
    expect: () => [
      const DataExportState(status: DataExportStatus.exporting),
      const DataExportState(
        status: DataExportStatus.failure,
        failure: NetworkFailure('network_error'),
      ),
    ],
    verify: (_) => verifyNever(() => sharer.shareFile(
          fileName: any(named: 'fileName'),
          bytes: any(named: 'bytes'),
          mimeType: any(named: 'mimeType'),
        )),
  );

  blocTest<DataExportCubit, DataExportState>(
    'a problem with the share sheet becomes share_failed',
    build: () {
      when(() => exportMyData(any())).thenAnswer((_) async => const Right<Failure, DataExportResult>(file));
      when(() => sharer.shareFile(
            fileName: any(named: 'fileName'),
            bytes: any(named: 'bytes'),
            mimeType: any(named: 'mimeType'),
          )).thenThrow(StateError('no share sheet'));
      return build();
    },
    act: (cubit) => cubit.export(),
    expect: () => [
      const DataExportState(status: DataExportStatus.exporting),
      const DataExportState(
        status: DataExportStatus.failure,
        failure: ServerFailure('share_failed'),
      ),
    ],
  );

  test('a second tap while the data is being read is ignored', () async {
    final gate = Completer<Either<Failure, DataExportResult>>();
    when(() => exportMyData(any())).thenAnswer((_) => gate.future);
    stubShare();
    final cubit = build();

    final first = cubit.export();
    await cubit.export();
    gate.complete(const Right<Failure, DataExportResult>(file));
    await first;

    verify(() => exportMyData(any())).called(1);
    expect(cubit.state.status, DataExportStatus.done);
    await cubit.close();
  });
}
