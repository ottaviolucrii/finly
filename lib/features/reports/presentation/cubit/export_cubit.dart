import 'package:finly/core/error/failure.dart';
import 'package:finly/core/share/file_sharer.dart';
import 'package:finly/core/utils/windows_1252.dart';
import 'package:finly/features/reports/domain/usecases/export_month_use_case.dart';
import 'package:finly/features/reports/presentation/cubit/export_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExportCubit extends Cubit<ExportState> {
  final ExportMonthUseCase _exportMonth;
  final FileSharer _sharer;

  ExportCubit({
    required ExportMonthUseCase exportMonth,
    required FileSharer sharer,
  })  : _exportMonth = exportMonth,
        _sharer = sharer,
        super(const ExportState());

  /// Builds the CSV of [month] and opens the share sheet with it.
  Future<void> export({
    required String workspaceId,
    required DateTime month,
  }) async {
    if (state.status == ExportStatus.exporting) return;

    emit(const ExportState(status: ExportStatus.exporting));
    final result = await _exportMonth(
      ExportMonthParams(workspaceId: workspaceId, month: month),
    );

    await result.fold<Future<void>>(
      (failure) async => emit(
        ExportState(status: ExportStatus.failure, failure: failure),
      ),
      (file) async {
        try {
          await _sharer.shareFile(
            fileName: file.fileName,
            // Windows-1252: what Excel in Brazil and the Android Sheets app
            // read correctly (they misread UTF-8 files).
            bytes: encodeWindows1252(file.content),
            mimeType: 'text/csv',
          );
          emit(ExportState(
            status: ExportStatus.done,
            rowCount: file.rowCount,
            truncated: file.truncated,
          ));
        } catch (e) {
          // A platform problem with the share sheet, not a data problem.
          debugPrint('Share failed: $e');
          emit(const ExportState(
            status: ExportStatus.failure,
            failure: ServerFailure('share_failed'),
          ));
        }
      },
    );
  }
}