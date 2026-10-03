/// Transaction types. [dbValue] is the label stored in PostgreSQL.
enum TransactionType {
  income('income'),
  expense('expense'),
  transferIn('transfer_in'),
  transferOut('transfer_out');

  final String dbValue;

  const TransactionType(this.dbValue);

  /// True when money comes into the account (BR-02: amounts are stored
  /// positive; the type gives the direction).
  bool get isCredit => this == income || this == transferIn;

  /// Transfers are two linked legs created by their own flow.
  bool get isTransfer => this == transferIn || this == transferOut;

  static TransactionType fromDb(String value) {
    for (final type in TransactionType.values) {
      if (type.dbValue == value) return type;
    }
    throw ArgumentError.value(value, 'value', 'Unknown transaction type');
  }
}