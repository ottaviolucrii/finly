/// A card invoice: open (cycle running), closed (cycle ended, waiting for
/// payment) or paid (SRS BR-13).
enum InvoiceStatus {
  open,
  closed,
  paid;

  /// The label stored in PostgreSQL is the enum name.
  String get dbValue => name;

  static InvoiceStatus fromDb(String value) {
    for (final status in InvoiceStatus.values) {
      if (status.name == value) return status;
    }
    throw ArgumentError.value(value, 'value', 'Unknown invoice status');
  }
}