/// Account types. [dbValue] is the label stored in PostgreSQL.
enum AccountType {
  checking('checking'),
  savings('savings'),
  investment('investment'),
  creditCard('credit_card');

  final String dbValue;

  const AccountType(this.dbValue);

  static AccountType fromDb(String value) {
    for (final type in AccountType.values) {
      if (type.dbValue == value) return type;
    }
    throw ArgumentError.value(value, 'value', 'Unknown account type');
  }
}