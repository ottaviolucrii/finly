import 'package:finly/core/error/failure.dart';
import 'package:finly/core/share/file_sharer.dart';
import 'package:finly/core/usecase/usecase.dart';
import 'package:finly/features/data_export/domain/usecases/export_my_data_use_case.dart';
import 'package:finly/features/data_export/presentation/cubit/data_export_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Reads all the data of the user and opens the share sheet with it as a JSON
/// file.
class DataExportCubit extends Cubit<DataExportState> {
  final ExportMyDataUseCase _exportMyData;
  final FileSharer _sharer;

  DataExportCubit({
    required ExportMyDataUseCase exportMyData,
    required FileSharer sharer,
  })  : _exportMyData = exportMyData,
        _sharer = sharer,
        super(const DataExportState());

  Future<void> export() async {
    if (state.status == DataExportStatus.exporting) return;

    emit(const DataExportState(status: DataExportStatus.exporting));
    final result = await _exportMyData(const NoParams());
    if (isClosed) return;

    await result.fold<Future<void>>(
      (failure) async => emit(
        DataExportState(status: DataExportStatus.failure, failure: failure),
      ),
      (file) async {
        try {
          await _sharer.shareFile(
            fileName: file.fileName,
            bytes: file.bytes,
            mimeType: 'application/json',
          );
          if (!isClosed) {
            emit(DataExportState(
              status: DataExportStatus.done,
              rowCount: file.rowCount,
              truncated: file.truncated,
            ));
          }
        } catch (e) {
          // A platform problem with the share sheet, not a data problem.
          debugPrint('Share failed: $e');
          if (!isClosed) {
            emit(const DataExportState(
              status: DataExportStatus.failure,
              failure: ServerFailure('share_failed'),
            ));
          }
        }
      },
    );
  }
}
