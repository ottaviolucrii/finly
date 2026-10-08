import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';

enum DataExportStatus { idle, exporting, done, failure }

class DataExportState extends Equatable {
  final DataExportStatus status;
  final Failure? failure;

  /// How many rows the file holds (when [status] is done).
  final int rowCount;

  /// True when a table was longer than the limit and the file is partial.
  final bool truncated;

  const DataExportState({
    this.status = DataExportStatus.idle,
    this.failure,
    this.rowCount = 0,
    this.truncated = false,
  });

  @override
  List<Object?> get props => [status, failure, rowCount, truncated];
}
