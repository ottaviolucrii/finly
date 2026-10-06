import 'package:equatable/equatable.dart';
import 'package:finly/core/error/failure.dart';

enum ExportStatus { idle, exporting, done, failure }

class ExportState extends Equatable {
  final ExportStatus status;
  final Failure? failure;

  /// How many transactions the file holds (when [status] is done).
  final int rowCount;

  /// True when the month was longer than the limit and the file is partial.
  final bool truncated;

  const ExportState({
    this.status = ExportStatus.idle,
    this.failure,
    this.rowCount = 0,
    this.truncated = false,
  });

  @override
  List<Object?> get props => [status, failure, rowCount, truncated];
}