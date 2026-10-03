/// Pending (expected), posted (confirmed) or failed (SRS BR-09).
enum TransactionStatus {
  pending,
  posted,
  failed;

  /// The label stored in PostgreSQL is the enum name.
  String get dbValue => name;

  static TransactionStatus fromDb(String value) {
    for (final status in TransactionStatus.values) {
      if (status.name == value) return status;
    }
    throw ArgumentError.value(value, 'value', 'Unknown transaction status');
  }
}