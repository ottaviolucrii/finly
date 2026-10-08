import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:finly/core/error/failure.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/data_export/domain/entities/data_export_result.dart';
import 'package:finly/features/data_export/domain/export_rules.dart';
import 'package:finly/features/data_export/domain/repositories/data_export_repository.dart';

/// All the data of the signed-in user as one JSON file (data portability). The
/// text is UTF-8, the encoding JSON files are expected to have.
class ExportMyDataUseCase implements UseCase<DataExportResult, NoParams> {
  final DataExportRepository _repository;
  final DateTime Function() _clock;

  /// [clock] gives "now" for the file name and the date inside; tests pass a
  /// fixed date.
  ExportMyDataUseCase(this._repository, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  @override
  Future<Either<Failure, DataExportResult>> call(NoParams params) async {
    final result = await _repository.readAll();

    Failure? failure;
    var rowCount = 0;
    var truncated = false;
    List<int> bytes = const [];
    final now = _clock();

    result.fold((f) {
      failure = f;
    }, (data) {
      rowCount = data.rowCount;
      truncated = data.truncatedTables.isNotEmpty;
      final document = buildExportDocument(data, now);
      bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(document));
    });

    final problem = failure;
    if (problem != null) return Left<Failure, DataExportResult>(problem);

    return Right<Failure, DataExportResult>(
      DataExportResult(
        fileName: exportFileName(now),
        bytes: bytes,
        rowCount: rowCount,
        truncated: truncated,
      ),
    );
  }
}
