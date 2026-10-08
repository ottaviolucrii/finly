import 'package:equatable/equatable.dart';

/// A file with all the data of the user, ready to be shared.
class DataExportResult extends Equatable {
  final String fileName;
  final List<int> bytes;

  /// How many rows of the database the file holds.
  final int rowCount;

  /// True when a table was longer than the limit and the file is partial.
  final bool truncated;

  const DataExportResult({
    required this.fileName,
    required this.bytes,
    required this.rowCount,
    required this.truncated,
  });

  @override
  List<Object?> get props => [fileName, bytes, rowCount, truncated];
}
